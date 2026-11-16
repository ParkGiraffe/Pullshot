import Foundation
import PullshotKit
import Testing
@testable import PullshotApp

@Suite("ExportPreview 테스트")
struct ExportPreviewTests {
    @Test func `다섯 개까지는 모두 보인다`() {
        let captures = (0 ..< 5).map { captureFixture("\($0).jpg", at: "2026-11-06 22:0\($0):00") }
        #expect(ExportPreview.lines(items(captures)) == [
            "001_20261106_220000.jpg", "002_20261106_220100.jpg", "003_20261106_220200.jpg",
            "004_20261106_220300.jpg", "005_20261106_220400.jpg",
        ])
    }

    @Test func `여섯 개부터는 앞 세 개와 마지막 하나 사이를 줄인다`() {
        let captures = (0 ..< 8).map { captureFixture("\($0).jpg", at: "2026-11-06 22:0\($0):00") }
        #expect(ExportPreview.lines(items(captures)) == [
            "001_20261106_220000.jpg", "002_20261106_220100.jpg", "003_20261106_220200.jpg", "…",
            "008_20261106_220700.jpg",
        ])
    }

    @Test func `폴더가 둘 이상이면 폴더 이름을 붙인다`() {
        let captures = [captureFixture("a.jpg"), captureFixture("b.jpg", game: "마리오 카트 월드")]
        #expect(ExportPreview.lines(items(captures)).map { $0.split(separator: "/")[0] } == [
            "젤다무쌍 봉인전기", "마리오 카트 월드",
        ])
    }

    private func items(_ captures: [Capture]) -> [TransferItem] {
        TransferItem.exports(
            captures,
            options: ExportOptions(baseFolder: URL(filePath: "/tmp/블로그"), naming: .numbered),
            timeZone: TimeZone(identifier: "Asia/Seoul") ?? .gmt
        )
    }
}
