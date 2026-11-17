import Foundation
import Testing
@testable import PullshotApp

@Suite("CaptureTimeText 테스트")
struct CaptureTimeTextTests {
    let text = CaptureTimeText(
        locale: Locale(identifier: "ko_KR"),
        timeZone: TimeZone(identifier: "Asia/Seoul") ?? .gmt
    )

    @Test func `두 시각의 때가 다르면 둘 다 때를 붙인다`() {
        #expect(text.timeRange(dateFixture("2026-11-06 16:05:00"), dateFixture("2026-11-06 18:20:00"))
            == "오후 4:05 ~ 저녁 6:20")
    }
}
