import Foundation
import PullshotKit

actor ConsoleWorker {
    private let queue = DispatchSerialQueue(label: "com.parkgiraffe.Pullshot.device")
    private let ledger: TransferLedger
    nonisolated let previewFolder: URL
    let log: FileLog
    private var transport: HostTransport?
    private var session: Session?
    private var serialNumber: String?

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }

    var ledgerIndex: LedgerIndex {
        ledger.index
    }

    var hasUsableSession: Bool {
        session?.isValid == true
    }

    init(
        ledgerDirectory: URL,
        previewFolder: URL = URL.temporaryDirectory.appending(path: "Pullshot-preview"),
        log: FileLog
    ) throws {
        ledger = try TransferLedger(directory: ledgerDirectory)
        self.previewFolder = previewFolder
        self.log = log
    }

    func open(_ console: AttachedConsole) throws -> DeviceInfo {
        close()
        let trace = { [log] (line: String) in
            guard UserDefaults.standard.bool(forKey: SettingsKey.isVerboseLogging.rawValue) else { return }
            log.write(line)
        }
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
        log.write("앨범 읽기: 사진과 동영상 \(scan.captures.count)개, 건너뜀 \(scan.skipped.count)개")
        return scan
    }

    func shouldAskFirstConnectQuestion() -> Bool {
        serialNumber.map(ledger.shouldAskFirstConnectQuestion) ?? false
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
        log.write("가져오기(\(kind.rawValue)): 저장 \(summary.saved.count)개, 건너뜀 \(summary.skipped)개, "
            + "실패 \(summary.failures.count)개, 가져오지 못함 \(summary.notAttempted)개")
        summary.failures.forEach { log.write("가져오지 못함: \(FileLog.describe($0.error))") }
        return summary
    }

    func downloadOriginal(_ capture: Capture) throws -> URL {
        let session = try requireSession()
        let folder = previewFolder.appending(path: capture.gameName)
        let file = folder.appending(path: capture.filename)
        if Self.hasDownloadedOriginal(of: capture, at: file) {
            return file
        }
        try? FileManager.default.removeItem(at: file)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try session.download(capture.handle, expectedSize: capture.size, to: file, isCancelled: { Task.isCancelled })
        return file
    }

    static func hasDownloadedOriginal(of capture: Capture, at file: URL) -> Bool {
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
