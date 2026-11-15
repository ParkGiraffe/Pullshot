import Testing
@testable import pullshot

@Suite("CaptureSelection 테스트")
struct CaptureSelectionTests {
    @Test func `파일 이름이나 게임과 파일 이름으로 고르고 못 찾은 이름을 알린다`() {
        let selection = CaptureSelection(
            names: ["a.jpg", "Mario Kart World/m.jpg", "zz.jpg"],
            game: nil,
            isAll: false,
            isNewOnly: false
        )
        let result = selection.choose(
            from: [captureFixture("a.jpg"), captureFixture("m.jpg", game: "Mario Kart World")],
            isNew: { _ in true }
        )

        #expect(result.chosen.map(\.filename) == ["a.jpg", "m.jpg"])
        #expect(result.missing == ["zz.jpg"])
    }

    @Test func `새 항목만 고르면 기록에 없는 캡처 중 그 게임 것만 남는다`() {
        let selection = CaptureSelection(names: [], game: "기타", isAll: false, isNewOnly: true)
        let captures = [
            captureFixture("a.jpg", game: nil),
            captureFixture("b.jpg", game: "기타"),
            captureFixture("c.jpg"),
        ]

        let chosen = selection.choose(from: captures, isNew: { $0.filename != "b.jpg" }).chosen

        #expect(chosen.map(\.filename) == ["a.jpg"])
    }
}
