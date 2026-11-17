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

    @Test func `같은 날 찍은 캡처는 월일 뒤에 시각 범위를 붙인다`() {
        #expect(text.span(dateFixture("2026-11-06 22:02:00"), dateFixture("2026-11-06 23:41:00"))
            == "11월 6일 밤 10:02 ~ 11:41")
    }

    @Test func `여러 날에 걸친 캡처는 날짜 범위만 쓴다`() {
        #expect(text.span(dateFixture("2026-10-29 10:00:00"), dateFixture("2026-11-16 21:00:00"))
            == "10월 29일~11월 16일")
    }
}
