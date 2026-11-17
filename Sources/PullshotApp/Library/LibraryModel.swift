import AppKit
import Observation
import PullshotKit

@MainActor @Observable
final class LibraryModel {
    enum Connection: Equatable {
        case searching
        case notInTransferMode(String)
        case reattachNeeded
        case connecting(AttachedConsole)
        case scanning(AttachedConsole, seen: Int)
        case ready(AttachedConsole, DeviceInfo)
        case failed(AttachedConsole, message: String)

        var console: AttachedConsole? {
            switch self {
            case let .connecting(console), let .scanning(console, _), let .ready(console, _), let .failed(console, _):
                console
            case .searching, .notInTransferMode, .reattachNeeded:
                nil
            }
        }
    }

    struct TransferRun {
        var folder: URL
        var progress: TransferProgress?
        var summary: TransferSummary?
        var errorMessage: String?

        var isFinished: Bool {
            summary != nil || errorMessage != nil
        }
    }

    private(set) var connection = Connection.searching
    private(set) var consoles: [AttachedConsole] = []
    private(set) var captures: [Capture] = []
    private(set) var index = LedgerIndex()
    private(set) var serialNumber: String?
    let isDemo: Bool
    var isAskingFirstConnect = false
    private(set) var firstConnectRecordedCount: Int?
    private(set) var firstConnectErrorMessage: String?
    private var firstConnectTask: Task<Void, Never>?
    private(set) var transferRun: TransferRun?
    private(set) var scope = LibraryScope.all
    private(set) var kind = KindFilter.all
    var gameSearch = ""
    var selection = GridSelection()
    var isInspectorShown = true
    let worker: DeviceWorker
    let thumbnails: ThumbnailStore
    let settings: AppSettings

    @ObservationIgnored private var monitor: ConsoleMonitor?
    @ObservationIgnored private(set) var isShuttingDown = false
    @ObservationIgnored private var deviceTask: Task<Void, Never>?
    @ObservationIgnored private var transferTask: Task<Void, Never>?
    @ObservationIgnored let previewPanel = PreviewPanelController()
    @ObservationIgnored var gridColumns = 1
    @ObservationIgnored var previewCapture: Capture?
    @ObservationIgnored var previewOriginals: [Capture.ID: URL] = [:]
    @ObservationIgnored var previewThumbnails: [Capture.ID: URL] = [:]
    @ObservationIgnored var previewTasks: [Capture.ID: Task<Void, Never>] = [:]

    init(worker: DeviceWorker, settings: AppSettings) {
        try? FileManager.default.removeItem(at: DeviceWorker.previewFolder)
        self.worker = worker
        self.settings = settings
        thumbnails = ThumbnailStore(worker: worker)
        isDemo = UserDefaults.standard.bool(forKey: SettingsKey.demoAlbum.rawValue)
        previewPanel.model = self
        guard isDemo else { return }
        consoles = [DemoAlbum.console]
        captures = DemoAlbum.captures(now: .now)
        serialNumber = DemoAlbum.info.serialNumber
        thumbnails.isDemo = true
        thumbnails.serialNumber = serialNumber
        connection = .ready(DemoAlbum.console, DemoAlbum.info)
    }

    var query: CaptureQuery {
        CaptureQuery(scope: scope, kind: kind)
    }

    var visibleCaptures: [Capture] {
        query.captures(in: captures, index: index, serialNumber: serialNumber ?? "", now: .now)
    }

    var emptyReason: EmptyReason? {
        query.emptyReason(in: captures, index: index, serialNumber: serialNumber ?? "", now: .now)
    }

    var selectedCaptures: [Capture] {
        visibleCaptures.filter { selection.selected.contains($0.id) }
    }

    var hasOpenSession: Bool {
        !isDemo && (connection.console != nil || isTransferring)
    }

    func shutdown() async {
        isShuttingDown = true
        monitor = nil
        let tasks = [deviceTask, transferTask, firstConnectTask].compactMap(\.self) + previewTasks.values
        stopPreview()
        tasks.forEach { $0.cancel() }
        for task in tasks {
            await task.value
        }
        await worker.close()
        try? FileManager.default.removeItem(at: DeviceWorker.previewFolder)
    }

    func watchConsoles() async {
        guard !isDemo, !isShuttingDown else { return }
        monitor = ConsoleMonitor()
        guard let changes = monitor?.changes else { return }
        await inspectConsoles()
        for await _ in changes {
            await inspectConsoles()
        }
    }

    func choose(_ console: AttachedConsole) {
        guard console != connection.console, !isTransferring else { return }
        open(console)
    }

    func show(_ scope: LibraryScope) {
        guard scope != self.scope else { return }
        self.scope = scope
        selection.clear()
        dismissTransferResult()
        previewPanel.close()
    }

    func filter(_ kind: KindFilter) {
        guard kind != self.kind else { return }
        self.kind = kind
        var kept = selection
        kept.keep(visibleCaptures.map(\.id))
        select(kept)
    }

    var isAnsweringFirstConnect: Bool {
        firstConnectTask != nil
    }

    func answerFirstConnect(_ answer: FirstConnectAnswer) {
        guard !isShuttingDown, !isAnsweringFirstConnect else { return }
        firstConnectErrorMessage = nil
        firstConnectTask = Task {
            do {
                let recordedCount = try await worker.answerFirstConnectQuestion(answer, captures: captures)
                guard !Task.isCancelled else { return }
                firstConnectRecordedCount = recordedCount
                index = await worker.index
            } catch {
                guard !Task.isCancelled else { return }
                worker.log.write("처음 연결 질문에 답하지 못함: \(FileLog.describe(error))")
                firstConnectErrorMessage = AppErrorMessages.message(for: error)
            }
            firstConnectTask = nil
        }
    }

    func cancelFirstConnectAnswer() {
        firstConnectTask?.cancel()
        firstConnectTask = nil
    }

    func retry() {
        guard case let .failed(console, _) = connection else { return }
        open(console)
    }

    private func inspectConsoles() async {
        guard !isShuttingDown else { return }
        consoles = ConsoleLocator.attached()
        guard let console = ConsoleChoice.next(current: connection.console, attached: consoles) else {
            leaveConsole()
            if connection != .reattachNeeded {
                connection = ConsoleLocator.idle().first.map { .notInTransferMode($0.name) } ?? .searching
            }
            await worker.close()
            return
        }
        if console != connection.console {
            open(console)
        }
    }

    private func open(_ console: AttachedConsole) {
        guard !isShuttingDown else { return }
        leaveConsole()
        connection = .connecting(console)
        deviceTask = Task { await load(console) }
    }

    func reopenIfSessionLost() async {
        guard await !worker.hasUsableSession, case let .ready(console, _) = connection else { return }
        open(console)
    }

    private func leaveConsole() {
        deviceTask?.cancel()
        cancelFirstConnectAnswer()
        stopPreview()
        previewOriginals = [:]
        previewThumbnails = [:]
        captures = []
        selection.clear()
        serialNumber = nil
        thumbnails.serialNumber = nil
        isAskingFirstConnect = false
        firstConnectRecordedCount = nil
        firstConnectErrorMessage = nil
        scope = .all
        gameSearch = ""
    }

    private func load(_ console: AttachedConsole) async {
        do {
            let info = try await worker.open(console, isVerbose: settings.isVerboseLog)
            try Task.checkCancellation()
            connection = .scanning(console, seen: 0)
            let scan = try await worker.scan { seen in
                guard seen.isMultiple(of: 100) else { return }
                Task { @MainActor in self.showScanProgress(seen, of: console) }
            }
            let index = await worker.index
            let needsFirstConnectQuestion = await worker.needsFirstConnectQuestion()
            try Task.checkCancellation()
            captures = scan.captures
            self.index = index
            serialNumber = info.serialNumber
            thumbnails.serialNumber = info.serialNumber
            isAskingFirstConnect = needsFirstConnectQuestion
            connection = .ready(console, info)
        } catch SessionError.needsUSBReset where connection.console == nil || connection.console == console {
            worker.log.write("연결하지 못함: \(FileLog.describe(SessionError.needsUSBReset))")
            connection = .reattachNeeded
        } catch {
            guard !Task.isCancelled else { return }
            worker.log.write("연결하지 못함: \(FileLog.describe(error))")
            connection = .failed(console, message: AppErrorMessages.message(for: error))
        }
    }

    private func showScanProgress(_ seen: Int, of console: AttachedConsole) {
        guard case let .scanning(scanned, previous) = connection, scanned == console, seen > previous else { return }
        connection = .scanning(console, seen: seen)
    }
}

extension LibraryModel {
    var importFolder: URL {
        settings.importFolder
    }

    var importOptions: ExportOptions {
        ExportOptions(
            baseFolder: importFolder,
            makesGameFolder: settings.makesGameFolder,
            naming: settings.exportNaming
        )
    }

    var isTransferring: Bool {
        transferRun.map { !$0.isFinished } ?? false
    }

    func captures(in target: ImportTarget) -> [Capture] {
        switch target {
        case .newItems:
            index.newCaptures(visibleCaptures, serialNumber: serialNumber ?? "")
        case .all:
            visibleCaptures
        case .selected:
            selectedCaptures
        }
    }

    func importItems(_ target: ImportTarget) -> [TransferItem] {
        target.items(captures(in: target), options: importOptions)
    }

    func cancelTransfer() {
        transferTask?.cancel()
    }

    func dismissTransferResult() {
        guard transferRun?.isFinished == true else { return }
        transferRun = nil
    }

    func revealInFinder() {
        guard let run = transferRun else { return }
        let saved = run.summary?.saved ?? []
        let folders = Set(saved.map { $0.deletingLastPathComponent() })
        NSWorkspace.shared.activateFileViewerSelecting(folders.count == 1 ? saved : [run.folder])
    }

    func startImport(_ target: ImportTarget) {
        guard !isShuttingDown, !isTransferring else { return }
        let items = importItems(target)
        stopPreview()
        transferRun = TransferRun(folder: importFolder)
        transferTask = Task {
            do {
                let summary = try await worker.transfer(items, as: target.kind) { progress in
                    Task { @MainActor in self.showTransferProgress(progress) }
                }
                transferRun?.summary = summary
            } catch {
                worker.log.write("옮기기를 마치지 못함: \(FileLog.describe(error))")
                transferRun?.errorMessage = AppErrorMessages.message(for: error)
            }
            index = await worker.index
            await reopenIfSessionLost()
        }
    }

    private func showTransferProgress(_ progress: TransferProgress) {
        guard isTransferring else { return }
        if let previous = transferRun?.progress, (progress.index, progress.bytes) < (previous.index, previous.bytes) {
            return
        }
        transferRun?.progress = progress
    }
}
