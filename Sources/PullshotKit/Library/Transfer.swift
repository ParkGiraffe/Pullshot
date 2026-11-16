import Foundation

/// 내려받기에 필요한 기기 동작입니다. `Session`이 따르고, 테스트는 가짜 기기로 바꿉니다.
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

/// 몇 번째 캡처를 받고 있고 그 캡처를 몇 바이트 받았는지입니다. 캡처를 시작할 때 0으로 한 번 알립니다.
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
    /// 같은 이름과 크기의 파일이 이미 있어 받지 않고 기록만 남긴 수입니다.
    public var skipped = 0
    public var failures: [TransferFailure] = []
    /// 연결이 끊기거나 취소돼 시작하지 못한 수입니다. 취소된 캡처도 여기에 셉니다.
    public var notAttempted = 0
    public var isCancelled = false
}

/// 가져오기와 내보내기를 합니다. 캡처마다 받고, 만든 날짜와 수정 날짜를 찍은 시각으로 맞추고, 옮긴 기록을 남깁니다.
/// 같은 파일이 이미 있어 건너뛴 캡처는 기록에 없을 때만 `foundInFolder`로 남겨, 지난번 옮긴 날이 바뀌지 않게 합니다.
public struct Transfer {
    private let source: DownloadSource
    private let ledger: TransferLedger
    private let serialNumber: String

    public init(source: DownloadSource, ledger: TransferLedger, serialNumber: String) {
        self.source = source
        self.ledger = ledger
        self.serialNumber = serialNumber
    }

    /// 한 캡처가 실패해도 나머지를 받고, 연결이 끊기거나 취소되면 멈춥니다.
    /// 기록을 쓰지 못할 때만 던집니다. 받은 파일을 기록 없이 두면 다음 연결에서 새 항목으로 다시 보이기 때문입니다.
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

    /// 날짜는 Finder에서 찍은 순서로 보이게 하려는 것이라, 맞추지 못해도 받기를 실패로 만들지 않습니다.
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
