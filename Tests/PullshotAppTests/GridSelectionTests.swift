import Testing
@testable import PullshotApp

@Suite("GridSelection 테스트")
struct GridSelectionTests {
    let order = ["a", "b", "c", "d", "e"]

    @Test func `그냥 누르면 그 캡처 하나만 고른다`() {
        var selection = GridSelection()
        selection.click("b", .only, in: order)
        selection.click("d", .only, in: order)
        #expect(selection.selected == ["d"])
        #expect(selection.anchor == "d")
    }

    @Test func `⌘를 누른 채 누르면 넣고 빼기를 바꾼다`() {
        var selection = GridSelection()
        selection.click("b", .only, in: order)
        selection.click("d", .toggle, in: order)
        selection.click("b", .toggle, in: order)
        #expect(selection.selected == ["d"])
    }

    @Test func `⇧를 누른 채 누르면 기준부터 누른 캡처까지 더한다`() {
        var selection = GridSelection()
        selection.click("b", .only, in: order)
        selection.click("d", .extend, in: order)
        #expect(selection.selected == ["b", "c", "d"])
        #expect(selection.anchor == "b")
    }

    @Test func `화살표는 기준에서 한 칸이나 한 줄 옮겨 하나만 고른다`() {
        let order = (0 ..< 10).map(String.init)
        var selection = GridSelection()
        selection.click("5", .only, in: order)
        selection.move(.right, columns: 4, in: order)
        #expect(selection.selected == ["6"])
        selection.move(.down, columns: 4, in: order)
        #expect(selection.selected == ["9"])
        selection.move(.down, columns: 4, in: order)
        #expect(selection.selected == ["9"])
        selection.move(.up, columns: 4, in: order)
        #expect(selection.selected == ["5"])
    }

    @Test func `고른 것이 없을 때 화살표는 첫 캡처를 고른다`() {
        var selection = GridSelection()
        selection.move(.down, columns: 4, in: order)
        #expect(selection.selected == ["a"])
    }

    @Test func `보이지 않게 된 캡처는 고른 것에서 뺀다`() {
        var selection = GridSelection()
        selection.selectAll(order)
        selection.click("e", .toggle, in: order)
        selection.keep(["a", "b"])
        #expect(selection.selected == ["a", "b"])
        #expect(selection.anchor == nil)
    }

    @Test func `미리보기는 기준 캡처를 먼저 받고 다음과 앞 캡처를 받아 둔다`() {
        var selection = GridSelection()
        selection.click("c", .only, in: order)
        #expect(selection.previewTargets(in: order) == ["c", "d", "b"])
    }

    @Test func `끝에 있는 기준 캡처는 한쪽 이웃만 받아 둔다`() {
        var selection = GridSelection()
        selection.click("a", .only, in: order)
        #expect(selection.previewTargets(in: order) == ["a", "b"])
        selection.click("e", .only, in: order)
        #expect(selection.previewTargets(in: order) == ["e", "d"])
    }

    @Test func `기준 캡처가 보이지 않으면 미리보기로 받을 것이 없다`() {
        var selection = GridSelection()
        selection.click("e", .only, in: order)
        #expect(selection.previewTargets(in: ["a", "b"]).isEmpty)
    }

    @Test func `열 수는 칸 최소 폭과 간격으로 정한다`() {
        #expect(GridSelection.columns(width: 900, minimum: 180, spacing: 3) == 4)
        #expect(GridSelection.columns(width: 100, minimum: 180, spacing: 3) == 1)
    }
}
