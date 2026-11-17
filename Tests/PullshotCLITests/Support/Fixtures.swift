import Foundation
@testable import PullshotKit

func timeZoneFixture() -> TimeZone {
    TimeZone(identifier: "Asia/Seoul") ?? .gmt
}

func captureFixture(
    _ filename: String,
    game: String? = "젤다무쌍 봉인전기",
    at capturedAt: String? = nil,
    size: UInt64? = 5,
    kind: Capture.Kind = .photo
) -> Capture {
    Capture(
        handle: 1,
        storageID: 0x0001_0001,
        filename: filename,
        size: size,
        capturedAt: capturedAt.flatMap { DateTimeString.parse($0, timeZone: timeZoneFixture()) },
        kind: kind,
        gameFolder: game
    )
}
