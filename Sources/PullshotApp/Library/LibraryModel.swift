import AppKit
import Observation
import PullshotKit

/// 창이 보이는 상태입니다. 기기 일은 `worker`에 맡기고, 받은 값만 들고 있습니다.
@MainActor @Observable
final class LibraryModel {
    enum Connection: Equatable {
        case searching
        /// 스위치가 꽂혀 있지만 PC로 복사 모드가 아닙니다. 값은 기기 이름입니다.
        case notInTransferMode(String)
        /// 남은 세션을 풀려고 USB 장치를 다시 붙였습니다. 스위치는 PC로 복사 모드에서 나갑니다.
        case reattachNeeded
        case connecting(AttachedConsole)
        case scanning(AttachedConsole, seen: Int)
        case ready(AttachedConsole, DeviceInfo)
        case failed(AttachedConsole, message: String)

        /// 열었거나 여는 중인 기기입니다.
        var console: AttachedConsole? {
            switch self {
            case let .connecting(console), let .scanning(console, _), let .ready(console, _), let .failed(console, _):
                console
            case .searching, .notInTransferMode, .reattachNeeded:
                nil
            }
        }
    }

    /// 가져오기나 내보내기 한 번입니다. 끝난 뒤에도 사용자가 닫거나 다른 것을 고를 때까지 결과를 남겨 둡니다.
    struct TransferRun {
        var kind: TransferKind
        /// 가져올 곳이나 내보낼 기준 폴더입니다.
        var folder: URL
        var progress: TransferProgress?
        var summary: TransferSummary?
        /// 옮긴 기록을 쓰지 못하는 등 결과 없이 멈췄을 때의 문구입니다. Kit이 이때는 결과 대신 오류를 던집니다.
        var errorMessage: String?

        var isFinished: Bool {
            summary != nil || errorMessage != nil
        }
    }

    private(set) var connection = Connection.searching
    /// PC로 복사 모드로 꽂힌 스위치입니다.
    private(set) var consoles: [AttachedConsole] = []
    private(set) var captures: [Capture] = []
    private(set) var index = LedgerIndex()
    private(set) var serialNumber: String?
    let isDemo: Bool
    var isAskingFirstConnect = false
    /// 처음 연결 질문에 답해 옮긴 기록에 넣은 캡처 수입니다. 답하기 전에는 nil입니다.
    private(set) var firstConnectRecordedCount: Int?
    /// 처음 연결 질문에 답하지 못했을 때 시트에 둘 문구입니다.
    private(set) var firstConnectErrorMessage: String?
    /// 처음 연결 질문의 답을 옮긴 기록에 남기는 일입니다. 폴더에서 찾기는 폴더가 크면 오래 걸려 시트에서 취소할 수 있고,
    /// 기기를 떠나거나 끝낼 때도 취소합니다.
    private var firstConnectTask: Task<Void, Never>?
    /// 옮기는 중이거나 사용자가 닫지 않은 옮기기 결과입니다. 기기가 빠져도 남겨 안내 화면에 보입니다.
    private(set) var transferRun: TransferRun?
    private(set) var scope = LibraryScope.all
    var kind = KindFilter.all
    var gameSearch = ""
    var selection = GridSelection()
    /// Quick Look으로 보는 원본입니다. Quick Look을 닫으면 nil이 됩니다.
    var previewURL: URL?
    /// 사용자가 툴바 단추로 둔 오른쪽 칸 상태입니다. 창이 좁아 접힐 때도 바꾸지 않습니다.
    var isInspectorShown = true
    let worker: DeviceWorker
    let thumbnails: ThumbnailStore
    let settings: AppSettings

    /// 감시를 놓으면 `changes`가 끝나므로 창이 있는 동안 쥐고 있다가 끝낼 때 놓습니다.
    @ObservationIgnored private var monitor: ConsoleMonitor?
    /// 끝내기가 기다리는 동안 감시 알림이나 단추가 새 기기 일을 시작하지 않게 합니다.
    /// 끝내기가 모은 작업 밖에서 세션이 열리면 닫지 못한 채 앱이 끝납니다.
    @ObservationIgnored private var isShuttingDown = false
    /// 연 기기에서 하는 일입니다. 기기를 바꾸거나 기기가 빠지면 취소합니다.
    @ObservationIgnored private var deviceTask: Task<Void, Never>?
    /// 기기가 빠져도 취소하지 않습니다. 끊긴 연결로 끝나야 결과에 받지 못한 수가 남습니다.
    @ObservationIgnored private var transferTask: Task<Void, Never>?
    /// 미리보기 원본을 받는 일입니다. 떠난 기기의 미리보기가 뒤늦게 뜨지 않도록 기기를 떠날 때 취소합니다.
    @ObservationIgnored private var previewTask: Task<Void, Never>?

    init(worker: DeviceWorker, settings: AppSettings) {
        // 앞 실행이 끝내기 전에 멈췄으면 미리보기 원본이 남아 있습니다.
        try? FileManager.default.removeItem(at: DeviceWorker.previewFolder)
        self.worker = worker
        self.settings = settings
        thumbnails = ThumbnailStore(worker: worker)
        isDemo = UserDefaults.standard.bool(forKey: SettingsKey.demoAlbum.rawValue)
        guard isDemo else { return }
        consoles = [DemoAlbum.console]
        captures = DemoAlbum.captures(now: .now)
        serialNumber = DemoAlbum.info.serialNumber
        thumbnails.isDemo = true
        thumbnails.serialNumber = serialNumber
        connection = .ready(DemoAlbum.console, DemoAlbum.info)
    }

    /// 사이드바 범위와 필터입니다.
    var query: CaptureQuery {
        CaptureQuery(scope: scope, kind: kind)
    }

    /// 사이드바 범위와 필터를 거쳐 격자에 보일 캡처입니다.
    var visibleCaptures: [Capture] {
        query.captures(in: captures, index: index, serialNumber: serialNumber ?? "", now: .now)
    }

    /// 격자가 비었을 때 그 까닭입니다.
    var emptyReason: EmptyReason? {
        query.emptyReason(in: captures, index: index, serialNumber: serialNumber ?? "", now: .now)
    }

    /// 고른 캡처를 격자에 보이는 순서(최신순)로 둡니다. 보이지 않게 된 캡처는 넣지 않습니다.
    var selectedCaptures: [Capture] {
        visibleCaptures.filter { selection.selected.contains($0.id) }.sorted(by: Capture.newestFirst)
    }

    /// 열었거나 여는 중인 세션이 있는지입니다. 기기가 빠졌어도 옮기기가 끝나기 전에는 세션을 쥐고 있습니다.
    /// 데모는 기기를 열지 않습니다.
    var hasOpenSession: Bool {
        !isDemo && (connection.console != nil || isTransferring)
    }

    /// 기준 캡처의 원본을 받아 Quick Look으로 엽니다. 앞서 받던 미리보기는 취소합니다.
    /// 데모 캡처는 기기에 없으므로 하지 않습니다. 옮기는 중에는 옮기기 뒤로 줄을 서 끝난 뒤에야 뜨므로 하지 않습니다.
    func preview() {
        guard !isDemo, !isShuttingDown, !isTransferring, let anchor = selection.anchor,
              let capture = captures.first(where: { $0.id == anchor })
        else {
            return
        }
        previewTask?.cancel()
        previewTask = Task {
            do {
                let file = try await worker.preview(capture)
                guard !Task.isCancelled else { return }
                previewURL = file
            } catch {
                guard !Task.isCancelled else { return }
                worker.log.write("미리보기를 받지 못함: \(FileLog.describe(error))")
                await reopenIfSessionLost()
            }
        }
    }

    /// 하던 일(연결과 훑기, 옮기기, 미리보기, 처음 연결 질문의 답)을 취소하고 끝나길 기다린 뒤 세션을 닫고 미리보기 원본을 지웁니다.
    /// 세션이 남으면 다음 연결이 USB 장치 리셋까지 갑니다.
    func shutdown() async {
        isShuttingDown = true
        monitor = nil
        let tasks = [deviceTask, transferTask, previewTask, firstConnectTask].compactMap(\.self)
        tasks.forEach { $0.cancel() }
        for task in tasks {
            await task.value
        }
        await worker.close()
        try? FileManager.default.removeItem(at: DeviceWorker.previewFolder)
    }

    /// 꽂힌 기기를 한 번 살피고, 그 뒤로는 기기가 꽂히거나 빠질 때마다 다시 살핍니다. 데모에서는 감시하지 않습니다.
    func watchConsoles() async {
        guard !isDemo, !isShuttingDown else { return }
        // 감시는 `monitor`만 쥐어, 끝내기가 놓으면 알림이 바로 끝나게 합니다.
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

    var isAnsweringFirstConnect: Bool {
        firstConnectTask != nil
    }

    /// 처음 연결 질문의 답을 옮긴 기록에 남깁니다. 폴더를 읽지 못하면 시트에 둘 문구를 남깁니다.
    func answerFirstConnect(_ answer: FirstConnectAnswer) {
        guard !isShuttingDown, !isAnsweringFirstConnect else { return }
        firstConnectErrorMessage = nil
        firstConnectTask = Task {
            do {
                firstConnectRecordedCount = try await worker.answerFirstConnectQuestion(answer, captures: captures)
                index = await worker.index
            } catch is CancellationError {
                // 사용자가 멈춘 것이라 실패로 남기지 않습니다.
            } catch {
                worker.log.write("처음 연결 질문에 답하지 못함: \(FileLog.describe(error))")
                firstConnectErrorMessage = AppErrorMessages.message(for: error)
            }
            firstConnectTask = nil
        }
    }

    func cancelFirstConnectAnswer() {
        firstConnectTask?.cancel()
    }

    func retry() {
        guard case let .failed(console, _) = connection else { return }
        open(console)
    }

    /// 연 기기가 그대로 꽂혀 있으면 두고, 빠졌으면 남은 기기를 엽니다. 남은 기기가 없으면 안내 화면으로 돌아갑니다.
    private func inspectConsoles() async {
        guard !isShuttingDown else { return }
        consoles = ConsoleLocator.attached()
        guard let console = ConsoleChoice.next(current: connection.console, attached: consoles) else {
            leaveConsole()
            // USB 리셋 뒤에는 스위치가 대기 상태로 다시 붙으므로, PC로 복사를 다시 켜 달라는 안내를 그대로 둡니다.
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

    /// 하던 일을 취소하고 그 기기를 엽니다. 앞 세션은 `worker.open`이 닫습니다.
    private func open(_ console: AttachedConsole) {
        guard !isShuttingDown else { return }
        leaveConsole()
        connection = .connecting(console)
        deviceTask = Task { await load(console) }
    }

    /// 옮기기나 미리보기가 세션을 버렸으면 그 기기를 다시 엽니다. 받는 중 Mac 디스크가 차는 것처럼 기기가 꽂힌 채
    /// 버려지면 감시 알림이 오지 않아, 다시 열지 않으면 버린 세션 위에서 연결됨으로 남습니다. 옮기기 결과는 남습니다.
    private func reopenIfSessionLost() async {
        guard await !worker.hasUsableSession, case let .ready(console, _) = connection else { return }
        open(console)
    }

    /// 하던 일을 취소하고 연 기기의 캡처, 고른 것, 질문을 치웁니다. 옮기기 결과는 안내 화면에 보이도록 남깁니다.
    private func leaveConsole() {
        deviceTask?.cancel()
        previewTask?.cancel()
        firstConnectTask?.cancel()
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

    /// 열고 훑습니다. 취소됐으면 뒤에 연 기기의 상태를 덮지 않도록 아무것도 바꾸지 않습니다.
    /// USB 리셋만은 리셋이 낸 빠짐 알림이 먼저 와서 취소됐을 수 있으므로, 다른 기기를 열고 있지 않으면 안내를 남깁니다.
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

    /// 훑기 진행은 큐를 거쳐 늦게 올 수 있으므로, 그 기기를 아직 훑는 중이고 앞 값보다 클 때만 반영합니다.
    private func showScanProgress(_ seen: Int, of console: AttachedConsole) {
        guard case let .scanning(scanned, previous) = connection, scanned == console, seen > previous else { return }
        connection = .scanning(console, seen: seen)
    }
}

/// 가져오기와 내보내기입니다. 옮기는 동안 기기가 빠져도 결과를 남겨 안내 화면에 보입니다.
extension LibraryModel {
    /// 가져올 곳입니다. 설정에서 고르지 않았으면 `~/Pictures/Pullshot`입니다.
    var importFolder: URL {
        settings.importFolder
    }

    /// 내보낼 기준 폴더와 규칙입니다. 기준 폴더를 고르기 전에는 nil입니다.
    var exportOptions: ExportOptions? {
        settings.exportFolder.map {
            ExportOptions(baseFolder: $0, makesGameFolder: settings.makesGameFolder, naming: settings.exportNaming)
        }
    }

    /// 옮기는 동안은 가져오기, 내보내기, 기기 전환을 끕니다.
    var isTransferring: Bool {
        transferRun.map { !$0.isFinished } ?? false
    }

    /// 보이는 캡처 가운데 새 항목을 가져올 곳에 가져옵니다.
    func importNew() {
        guard let serialNumber else { return }
        let captures = index.newCaptures(visibleCaptures, serialNumber: serialNumber)
        transfer(TransferItem.imports(captures, into: importFolder), as: .imported, folder: importFolder)
    }

    /// 고른 캡처를 기준 폴더로 내보냅니다. 기준 폴더를 고르기 전에는 하지 않습니다.
    func export() {
        guard let exportOptions else { return }
        transfer(
            TransferItem.exports(selectedCaptures, options: exportOptions),
            as: .exported,
            folder: exportOptions.baseFolder
        )
    }

    /// Kit이 받던 파일의 남은 데이터를 끝까지 읽어 버리고 멈춥니다. 결과에 취소했다고 남습니다.
    func cancelTransfer() {
        transferTask?.cancel()
    }

    func dismissTransferResult() {
        guard transferRun?.isFinished == true else { return }
        transferRun = nil
    }

    /// 사이드바에서 고른 범위를 봅니다. 고른 것과 끝난 옮기기 결과는 앞 범위의 것이라 치웁니다.
    func show(_ scope: LibraryScope) {
        guard scope != self.scope else { return }
        self.scope = scope
        selection.clear()
        dismissTransferResult()
    }

    /// 격자에서 고른 것을 바꿉니다. 끝난 옮기기 결과는 앞서 고른 것의 결과라 닫아, 결과 칸이 내보내기 단추 자리를
    /// 차지하지 않게 합니다. 기기가 빠져 고른 것을 지울 때는 여기를 거치지 않아 결과가 안내 화면에 남습니다.
    func select(_ selection: GridSelection) {
        guard selection != self.selection else { return }
        self.selection = selection
        dismissTransferResult()
    }

    /// 저장한 파일이 한 폴더에 있으면 그 파일들을, 여러 폴더에 있거나 저장한 파일이 없으면 기준 폴더를 Finder에서 보입니다.
    func revealInFinder() {
        guard let run = transferRun else { return }
        let saved = run.summary?.saved ?? []
        let folders = Set(saved.map { $0.deletingLastPathComponent() })
        NSWorkspace.shared.activateFileViewerSelecting(folders.count == 1 ? saved : [run.folder])
    }

    /// 옮기기를 시작합니다. 끝나면 결과와 옮긴 기록 색인을 맞춥니다.
    private func transfer(_ items: [TransferItem], as kind: TransferKind, folder: URL) {
        guard !isShuttingDown, !isTransferring else { return }
        transferRun = TransferRun(kind: kind, folder: folder)
        transferTask = Task {
            do {
                let summary = try await worker.transfer(items, as: kind) { progress in
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

    /// 옮기기 진행도 큐를 거쳐 늦게 올 수 있으므로, 옮기는 중이고 앞 값보다 뒤일 때만 반영합니다.
    private func showTransferProgress(_ progress: TransferProgress) {
        guard isTransferring else { return }
        if let previous = transferRun?.progress, (progress.index, progress.bytes) < (previous.index, previous.bytes) {
            return
        }
        transferRun?.progress = progress
    }
}
