import Foundation
import PullshotKit
import Testing
@testable import PullshotApp

@Suite("ExportPreview 테스트")
struct ExportPreviewTests {
    @Test func `여섯 개부터는 앞 세 개와 마지막 하나 사이를 줄인다`() {
        let captures = (0 ..< 8).map { captureFixture("\($0).jpg", at: "2026-11-06 22:0\($0):00") }
        let items = TransferItem.exports(
            captures,
            options: ExportOptions(baseFolder: URL(filePath: "/tmp/블로그"), naming: .numbered),
            timeZone: TimeZone(identifier: "Asia/Seoul") ?? .gmt
        )
        #expect(ExportPreview.lines(items) == [
            "001_20261106_220000.jpg", "002_20261106_220100.jpg", "003_20261106_220200.jpg", "…",
            "008_20261106_220700.jpg",
        ])
    }
}
