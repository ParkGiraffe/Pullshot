import Foundation
import PullshotKit

/// 기기와 주고받는 일을 모두 맡습니다. `Session`, `HostTransport`, `TransferLedger`는 밖으로 내보내지 않고
/// `Sendable` 값만 돌려줍니다. 취소는 부른 작업의 `Task.isCancelled`를 Kit에 넘겨 확인합니다.
actor DeviceWorker {
    /// 미리보기 원본을 받는 곳입니다. 앱을 시작할 때와 끝낼 때 지웁니다.
    static let previewFolder = URL.temporaryDirectory.appending(path: "Pullshot-preview")

    /// 블로킹 USB 읽기가 협력 스레드 풀을 막지 않도록 전용 큐에서 돕니다.
    private let queue = DispatchSerialQueue(label: "com.parkgiraffe.Pullshot.device")
    private let ledger: TransferLedger
    private let log: FileLog
    private var transport: HostTransport?
    private var session: Session?
    /// 연 기기의 일련번호입니다. 닫으면 nil입니다.
    private(set) var serialNumber: String?

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }

    var index: LedgerIndex {
        ledger.index
    }

    init(ledgerDirectory: URL, log: FileLog) throws {
        ledger = try TransferLedger(directory: ledgerDirectory)
        self.log = log
    }

    /// 앞 세션을 닫고 새로 엽니다. 남은 세션을 풀려고 USB 장치를 다시 붙였으면 `needsUSBReset`을 그대로 던지고,
    /// 기기가 다시 나타나면 부른 쪽이 다시 엽니다.
    func open(_ console: AttachedConsole, isVerbose: Bool) throws -> DeviceInfo {
        close()
        let trace: ((String) -> Void)? = isVerbose ? { [log] in log.write($0) } : nil
        let transport = try openTransport(console, trace: trace)
        let session = Session(transport: transport, trace: trace)
        let info: DeviceInfo
        do {
            info = try session.open()
        } catch {
            transport.close()
            throw error
        }
        self.transport = transport
        self.session = session
        serialNumber = info.serialNumber
        log.write("연결: \(console.model.name), 펌웨어 \(info.deviceVersion)")
        return info
    }

    func scan(progress: @escaping @Sendable (Int) -> Void) throws -> AlbumScan {
        let scan = try AlbumScanner(source: requireSession())
            .scan(progress: progress, isCancelled: { Task.isCancelled })
        log.write("훑기: 캡처 \(scan.captures.count)개, 건너뜀 \(scan.skipped.count)개")
        return scan
    }

    func needsFirstConnectQuestion() -> Bool {
        serialNumber.map(ledger.needsFirstConnectQuestion) ?? false
    }

    func answerFirstConnectQuestion(_ answer: FirstConnectAnswer, captures: [Capture]) throws -> Int {
        guard let serialNumber else { throw SessionError.invalidated }
        return try ledger.answerFirstConnectQuestion(
            answer,
            captures: captures,
            serialNumber: serialNumber,
            isCancelled: { Task.isCancelled }
        )
    }

    /// 화면 밖으로 나간 칸의 요청이 기기에 가지 않도록 보내기 전에 취소를 확인합니다.
    func thumbnail(of capture: Capture) throws -> Data {
        let session = try requireSession()
        try Task.checkCancellation()
        return try session.thumbnail(capture.handle)
    }

    /// 진행은 캡처를 시작할 때와 앞 알림에서 0.1초가 지났을 때만 넘깁니다. 받는 조각마다 넘기면 화면이 따라가지 못합니다.
    func transfer(
        _ items: [TransferItem],
        as kind: TransferKind,
        progress: @escaping @Sendable (TransferProgress) -> Void
    ) throws -> TransferSummary {
        guard let serialNumber else { throw SessionError.invalidated }
        var reportedAt = ContinuousClock.now
        let summary = try Transfer(source: requireSession(), ledger: ledger, serialNumber: serialNumber).run(
            items,
            as: kind,
            progress: { update in
                guard update.bytes == 0 || ContinuousClock.now - reportedAt >= .milliseconds(100) else { return }
                reportedAt = .now
                progress(update)
            },
            isCancelled: { Task.isCancelled }
        )
        log.write("옮기기(\(kind.rawValue)): 저장 \(summary.saved.count)개, 건너뜀 \(summary.skipped)개, "
            + "실패 \(summary.failures.count)개, 받지 못함 \(summary.notAttempted)개")
        summary.failures.forEach { log.write("옮기지 못함: \(FileLog.describe($0.error))") }
        return summary
    }

    /// `<미리보기 폴더>/<게임 이름>/<파일 이름>`에 받습니다. 크기가 같은 파일이 있으면 다시 받지 않고,
    /// 옮긴 기록에는 남기지 않습니다.
    func preview(_ capture: Capture) throws -> URL {
        let session = try requireSession()
        let folder = Self.previewFolder.appending(path: capture.gameName)
        let file = folder.appending(path: capture.filename)
        let attributes = try? FileManager.default.attributesOfItem(atPath: file.path(percentEncoded: false))
        if let size = capture.size, (attributes?[.size] as? NSNumber)?.uint64Value == size {
            return file
        }
        try? FileManager.default.removeItem(at: file)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try session.download(capture.handle, expectedSize: capture.size, to: file, isCancelled: { Task.isCancelled })
        return file
    }

    /// 세션을 닫고 인터페이스를 놓습니다. 기기에 세션이 남으면 다음 연결이 USB 장치 리셋까지 갑니다.
    func close() {
        session?.close()
        transport?.close()
        session = nil
        transport = nil
        serialNumber = nil
    }

    private func requireSession() throws -> Session {
        guard let session else { throw SessionError.invalidated }
        return session
    }

    /// 다시 붙은 기기는 노드가 먼저 보이고 사진 전송 인터페이스는 조금 늦게 생기므로, 그동안은 몇 초 더 기다립니다.
    private func openTransport(_ console: AttachedConsole, trace: ((String) -> Void)?) throws -> HostTransport {
        let deadline = Date().addingTimeInterval(5)
        while true {
            do {
                return try HostTransport(console: console, trace: trace)
            } catch ConsoleAccessError.noStillImageInterface where Date() < deadline {
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
    }
}
