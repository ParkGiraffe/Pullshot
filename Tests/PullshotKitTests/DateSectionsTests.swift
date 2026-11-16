import Foundation
import Testing
@testable import PullshotKit

@Suite("DateSections 테스트")
struct DateSectionsTests {
    @Test func `달과 날로 묶고 최근 것이 먼저다`() {
        let sections = DateSections([
            captureFixture("a.jpg", at: "2026-10-31 13:20:00"),
            captureFixture("b.jpg", at: "2026-11-06 22:02:00"),
            captureFixture("c.jpg", at: "2026-11-06 23:48:00"),
            captureFixture("d.jpg", at: "2026-11-02 14:40:00"),
        ], calendar: calendarFixture())

        #expect(sections.months.map { $0.days.map { $0.captures.map(\.filename) } }
            == [[["c.jpg", "b.jpg"], ["d.jpg"]], [["a.jpg"]]])
        #expect(sections.months[0].start == dateFixture("2026-11-01 00:00:00"))
        #expect(sections.months[0].days[1].start == dateFixture("2026-11-02 00:00:00"))
    }

    @Test func `자정 직전과 자정은 다른 날이다`() {
        let sections = DateSections([
            captureFixture("a.jpg", at: "2026-11-06 23:59:59"),
            captureFixture("b.jpg", at: "2026-11-07 00:00:00"),
        ], calendar: calendarFixture())

        #expect(sections.months[0].days.map { $0.captures.map(\.filename) } == [["b.jpg"], ["a.jpg"]])
    }

    @Test func `찍은 시각을 모르는 캡처는 날짜 묶음 밖에 따로 둔다`() {
        let sections = DateSections(
            [captureFixture("x.jpg", at: nil), captureFixture("a.jpg")],
            calendar: calendarFixture()
        )

        #expect(sections.months.count == 1)
        #expect(sections.undated.map(\.filename) == ["x.jpg"])
    }
}
