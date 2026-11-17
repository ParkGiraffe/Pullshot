import Foundation

public protocol DownloadSource: AnyObject {
    var isValid: Bool { get }
    func download(
        _ handle: UInt32,
        expectedSize: UInt64?,
        to destination: URL,
        progress: (UInt64) -> Void,
        isCancelled: () -> Bool
    ) throws
}

extension Session: DownloadSource {}

public struct TransferProgress: Equatable, Sendable {
    public var index: Int
    public var total: Int
    public var capture: Capture
    public var bytes: UInt64
}

public struct TransferFailure: Sendable {
    public var capture: Capture
    public var error: any Error
}

public struct TransferSummary: Sendable {
    public var saved: [URL] = []
    public var skipped = 0
    public var failures: [TransferFailure] = []
    public var notAttempted = 0
    public var isCancelled = false
}

public struct Transfer {
    private let source: DownloadSource
    private let ledger: TransferLedger
    private let serialNumber: String

    public init(source: DownloadSource, ledger: TransferLedger, serialNumber: String) {
        self.source = source
        self.ledger = ledger
        self.serialNumber = serialNumber
    }

    public func run(
        _ items: [TransferItem],
        as kind: TransferKind,
        progress: (TransferProgress) -> Void = { _ in },
        isCancelled: () -> Bool = { false }
    ) throws -> TransferSummary {
        var summary = TransferSummary()
        for (index, item) in items.enumerated() {
            guard !isCancelled() else {
                summary.isCancelled = true
                summary.notAttempted = items.count - index
                return summary
            }
            func report(_ bytes: UInt64) {
                progress(TransferProgress(index: index, total: items.count, capture: item.capture, bytes: bytes))
            }
            report(0)

            let decision: DestinationNamer.Decision
            do {
                try FileManager.default.createDirectory(at: item.folder, withIntermediateDirectories: true)
                decision = DestinationNamer.decide(filename: item.filename, size: item.capture.size, in: item.folder)
            } catch {
                summary.failures.append(TransferFailure(capture: item.capture, error: error))
                continue
            }
            switch decision {
            case .skip:
                summary.skipped += 1
                if !ledger.index.isTransferred(item.capture, serialNumber: serialNumber) {
                    try ledger.record([item.capture], serialNumber: serialNumber, as: .foundInFolder)
                }
            case let .write(destination):
                do {
                    try source.download(
                        item.capture.handle,
                        expectedSize: item.capture.size,
                        to: destination,
                        progress: report,
                        isCancelled: isCancelled
                    )
                } catch SessionError.cancelled {
                    summary.isCancelled = true
                    summary.notAttempted = items.count - index
                    return summary
                } catch {
                    summary.failures.append(TransferFailure(capture: item.capture, error: error))
                    guard source.isValid else {
                        summary.notAttempted = items.count - index - 1
                        return summary
                    }
                    continue
                }
                setCaptureDates(of: destination, to: item.capture.capturedAt)
                summary.saved.append(destination)
                try ledger.record([item.capture], serialNumber: serialNumber, as: kind)
            }
        }
        return summary
    }

    private func setCaptureDates(of file: URL, to date: Date?) {
        guard let date else { return }
        do {
            try FileManager.default.setAttributes(
                [.creationDate: date, .modificationDate: date],
                ofItemAtPath: file.path(percentEncoded: false)
            )
        } catch {
            Log.library.error("찍은 시각을 맞추지 못했습니다: \(String(describing: error), privacy: .private)")
        }
    }
}
