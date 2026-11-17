import Foundation
@testable import PullshotKit

final class FakeDownloadSource: DownloadSource {
    enum Outcome {
        case write
        case fail(any Error)
        case disconnect
        case cancel
    }

    var outcomes: [UInt32: Outcome] = [:]
    private(set) var downloaded: [UInt32] = []
    private(set) var isValid = true

    func download(
        _ handle: UInt32,
        expectedSize: UInt64?,
        to destination: URL,
        progress: (UInt64) -> Void,
        isCancelled _: () -> Bool
    ) throws {
        downloaded.append(handle)
        switch outcomes[handle] ?? .write {
        case .write:
            let size = expectedSize ?? 1
            try Data(repeating: 0xAB, count: Int(size)).write(to: destination)
            progress(size)
        case let .fail(error):
            throw error
        case .disconnect:
            isValid = false
            throw SessionError.transport(.disconnected)
        case .cancel:
            throw SessionError.cancelled
        }
    }
}
