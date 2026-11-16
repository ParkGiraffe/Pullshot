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
    let worker: DeviceWorker

    /// 감시를 놓으면 `changes`가 끝나므로 창이 있는 동안 쥐고 있습니다.
    @ObservationIgnored private var monitor: ConsoleMonitor?
    /// 연 기기에서 하는 일입니다. 기기를 바꾸거나 기기가 빠지면 취소합니다.
    @ObservationIgnored private var deviceTask: Task<Void, Never>?

    init(worker: DeviceWorker) {
        self.worker = worker
        isDemo = UserDefaults.standard.bool(forKey: SettingsKey.demoAlbum.rawValue)
        guard isDemo else { return }
        consoles = [DemoAlbum.console]
        captures = DemoAlbum.captures(now: .now)
        serialNumber = DemoAlbum.info.serialNumber
        connection = .ready(DemoAlbum.console, DemoAlbum.info)
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

    /// 하던 일을 취소하고 연 기기의 캡처와 질문을 치웁니다.
    private func leaveConsole() {
        deviceTask?.cancel()
        captures = []
        serialNumber = nil
        isAskingFirstConnect = false
    }

    /// 열고 훑습니다. 취소됐으면 뒤에 연 기기의 상태를 덮지 않도록 아무것도 바꾸지 않습니다.
    private func load(_ console: AttachedConsole) async {
        do {
            let isVerbose = UserDefaults.standard.bool(forKey: SettingsKey.isVerboseLog.rawValue)
            let info = try await worker.open(console, isVerbose: isVerbose)
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
            isAskingFirstConnect = needsFirstConnectQuestion
            connection = .ready(console, info)
        } catch {
            guard !Task.isCancelled else { return }
            worker.log.write("연결하지 못함: \(FileLog.describe(error))")
            connection = error as? SessionError == .needsUSBReset
                ? .reattachNeeded
                : .failed(console, message: AppErrorMessages.message(for: error))
        }
    }

    /// 훑기 진행은 큐를 거쳐 늦게 올 수 있으므로, 그 기기를 아직 훑는 중이고 앞 값보다 클 때만 반영합니다.
    private func showScanProgress(_ seen: Int, of console: AttachedConsole) {
        guard case let .scanning(scanned, previous) = connection, scanned == console, seen > previous else { return }
        connection = .scanning(console, seen: seen)
    }
}
