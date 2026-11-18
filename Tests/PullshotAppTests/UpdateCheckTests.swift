import Foundation
import Testing
@testable import PullshotApp

@Suite("UpdateCheck 테스트")
struct UpdateCheckTests {
    @Test func `최신 릴리스가 지금 버전보다 높을 때만 새 버전으로 알린다`() throws {
        let page = try #require(URL(string: "https://github.com/ParkGiraffe/Pullshot/releases/tag/v0.1.10"))
        #expect(UpdateCheck(current: "0.1.9", status: 200, body: release("v0.1.10")) == .available(
            version: "0.1.10",
            page: page
        ))
        #expect(UpdateCheck(current: "0.1.10", status: 200, body: release("v0.1.10")) == .upToDate)
        #expect(UpdateCheck(current: "0.2", status: 200, body: release("v0.1.10")) == .upToDate)
    }

    @Test func `릴리스가 없으면 최신으로, 그 밖의 응답은 실패로 본다`() {
        #expect(UpdateCheck(current: "0.1.0", status: 404, body: Data()) == .upToDate)
        #expect(UpdateCheck(current: "0.1.0", status: 403, body: Data()) == .failed)
        #expect(UpdateCheck(current: "0.1.0", status: 200, body: Data("{}".utf8)) == .failed)
    }

    private func release(_ tag: String) -> Data {
        let page = "https://github.com/ParkGiraffe/Pullshot/releases/tag/\(tag)"
        return Data(#"{"tag_name": "\#(tag)", "html_url": "\#(page)"}"#.utf8)
    }
}
