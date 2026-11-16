import Foundation
@testable import PullshotKit

/// 서울 시간대입니다. 목록의 시각이 실행하는 곳의 시간대에 기대지 않게 합니다.
func timeZoneFixture() -> TimeZone {
    TimeZone(identifier: "Asia/Seoul") ?? .gmt
}

/// 고르기와 목록 테스트에 쓰는 캡처입니다. 찍은 시각은 PTP 날짜 글(`20261114T211205`)을 서울 시각으로 읽습니다.
/// Kit 테스트 타깃의 픽스처는 이 타깃에서 쓸 수 없어 따로 둡니다.
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
