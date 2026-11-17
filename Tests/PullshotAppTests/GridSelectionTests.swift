import PullshotKit
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

    @Test(arguments: [
        ("c.jpg", ["c.jpg", "d.jpg", "b.jpg"]),
        ("a.jpg", ["a.jpg", "b.jpg"]),
        ("e.jpg", ["e.jpg", "d.jpg"]),
    ])
    func `미리보기는 기준 캡처를 먼저 받고 있는 쪽의 다음과 앞 사진을 받아 둔다`(anchor: String, targets: [String]) {
        let captures = capturesFixture(["a.jpg", "b.jpg", "c.jpg", "d.jpg", "e.jpg"])
        #expect(previewTargets(anchor: anchor, in: captures) == targets)
    }

    @Test func `동영상 이웃은 받아 두지 않고 기준 캡처는 동영상도 받는다`() {
        let captures = capturesFixture(["a.mp4", "b.mp4", "c.jpg"])
        #expect(previewTargets(anchor: "b.mp4", in: captures) == ["b.mp4", "c.jpg"])
    }

    @Test func `기준 캡처가 보이지 않으면 미리보기로 받을 것이 없다`() {
        let captures = capturesFixture(["a.jpg", "b.jpg", "c.jpg"])
        var selection = GridSelection()
        selection.click(captures[2].id, .only, in: captures.map(\.id))
        #expect(selection.previewTargets(in: Array(captures.prefix(2))).isEmpty)
    }
}

/// 파일 이름으로 만든 캡처입니다. `.mp4`로 끝나면 동영상입니다.
private func capturesFixture(_ filenames: [String]) -> [Capture] {
    filenames.map { captureFixture($0, kind: $0.hasSuffix(".mp4") ? .video : .photo) }
}

/// `anchor`를 그냥 눌러 고른 뒤 미리보기로 받을 캡처의 파일 이름입니다.
private func previewTargets(anchor: String, in captures: [Capture]) -> [String] {
    var selection = GridSelection()
    let anchorID = captures.first { $0.filename == anchor }?.id ?? ""
    selection.click(anchorID, .only, in: captures.map(\.id))
    return selection.previewTargets(in: captures).map(\.filename)
}
