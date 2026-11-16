import Foundation
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

    private(set) var connection = Connection.searching
    /// PC로 복사 모드로 꽂힌 스위치입니다.
    private(set) var consoles: [AttachedConsole] = []
    private(set) var captures: [Capture] = []
    private(set) var index = LedgerIndex()
    private(set) var serialNumber: String?
    let isDemo: Bool
    var isAskingFirstConnect = false
    var scope = LibraryScope.all
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

    /// 감시를 놓으면 `changes`가 끝나므로 창이 있는 동안 쥐고 있습니다.
    @ObservationIgnored private var monitor: ConsoleMonitor?
    /// 연 기기에서 하는 일입니다. 기기를 바꾸거나 기기가 빠지면 취소합니다.
    @ObservationIgnored private var deviceTask: Task<Void, Never>?

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

    /// 사이드바 범위와 종류 필터를 거쳐 격자에 보일 캡처입니다.
    var visibleCaptures: [Capture] {
        CaptureQuery(scope: scope, kind: kind)
            .captures(in: captures, index: index, serialNumber: serialNumber ?? "", now: .now)
    }

    /// 고른 캡처를 격자에 보이는 순서(최신순)로 둡니다. 보이지 않게 된 캡처는 넣지 않습니다.
    var selectedCaptures: [Capture] {
        visibleCaptures.filter { selection.selected.contains($0.id) }.sorted(by: Capture.newestFirst)
    }

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

    /// 기준 캡처의 원본을 받아 Quick Look으로 엽니다. 데모 캡처는 기기에 없으므로 하지 않습니다.
    func preview() async {
        guard !isDemo, let anchor = selection.anchor, let capture = captures.first(where: { $0.id == anchor }) else {
            return
        }
        do {
            previewURL = try await worker.preview(capture)
        } catch {
            worker.log.write("미리보기를 받지 못함: \(FileLog.describe(error))")
        }
    }

    /// 꽂힌 기기를 한 번 살피고, 그 뒤로는 기기가 꽂히거나 빠질 때마다 다시 살핍니다. 데모에서는 감시하지 않습니다.
    func watchConsoles() async {
        guard !isDemo else { return }
        let monitor = ConsoleMonitor()
        self.monitor = monitor
        await inspectConsoles()
        for await _ in monitor.changes {
            await inspectConsoles()
        }
    }

    func choose(_ console: AttachedConsole) async {
        guard console != connection.console else { return }
        open(console)
    }

    func retry() async {
        guard case let .failed(console, _) = connection else { return }
        open(console)
    }

    /// 연 기기가 그대로 꽂혀 있으면 두고, 빠졌으면 남은 기기를 엽니다. 남은 기기가 없으면 안내 화면으로 돌아갑니다.
    private func inspectConsoles() async {
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
        leaveConsole()
        connection = .connecting(console)
        deviceTask = Task { await load(console) }
    }

    /// 하던 일을 취소하고 연 기기의 캡처, 고른 것, 질문을 치웁니다.
    private func leaveConsole() {
        deviceTask?.cancel()
        captures = []
        selection.clear()
        serialNumber = nil
        thumbnails.serialNumber = nil
        isAskingFirstConnect = false
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
