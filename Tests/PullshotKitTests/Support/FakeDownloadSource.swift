import Foundation
@testable import PullshotKit

/// 내려받기를 흉내 내는 기기입니다. 캡처마다 결과를 정해 둘 수 있습니다.
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

    /// `write`는 기대 크기만큼(모르면 1바이트) 쓰고 다 쓴 뒤 진행을 한 번 알립니다.
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
