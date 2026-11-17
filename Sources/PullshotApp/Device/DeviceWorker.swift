import Foundation
import PullshotKit

actor DeviceWorker {
    static let previewFolder = URL.temporaryDirectory.appending(path: "Pullshot-preview")

    private let queue = DispatchSerialQueue(label: "com.parkgiraffe.Pullshot.device")
    private let ledger: TransferLedger
    let log: FileLog
    private var transport: HostTransport?
    private var session: Session?
    private var serialNumber: String?

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }

    var index: LedgerIndex {
        ledger.index
    }

    var hasUsableSession: Bool {
        session?.isValid == true
    }

    init(ledgerDirectory: URL, log: FileLog) throws {
        ledger = try TransferLedger(directory: ledgerDirectory)
        self.log = log
    }

    func open(_ console: AttachedConsole, isVerbose: Bool) throws -> DeviceInfo {
        close()
        let trace: ((String) -> Void)? = isVerbose ? { [log] in log.write($0) } : nil
        let transport = try HostTransport.open(console, trace: trace, waitingUpTo: 5, isCancelled: { Task.isCancelled })
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

    func thumbnail(of capture: Capture) throws -> Data {
        let session = try requireSession()
        try Task.checkCancellation()
        return try session.thumbnail(capture.handle)
    }

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

    func preview(_ capture: Capture) throws -> URL {
        let session = try requireSession()
        let folder = Self.previewFolder.appending(path: capture.gameName)
        let file = folder.appending(path: capture.filename)
        if Self.hasPreview(of: capture, at: file) {
            return file
        }
        try? FileManager.default.removeItem(at: file)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try session.download(capture.handle, expectedSize: capture.size, to: file, isCancelled: { Task.isCancelled })
        return file
    }

    static func hasPreview(of capture: Capture, at file: URL) -> Bool {
        let attributes = try? FileManager.default.attributesOfItem(atPath: file.path(percentEncoded: false))
        return capture.size != nil && (attributes?[.size] as? NSNumber)?.uint64Value == capture.size
    }

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
}
