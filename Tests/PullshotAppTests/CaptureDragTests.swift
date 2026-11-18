import Foundation
import PullshotKit
import Testing
@testable import PullshotApp

@Suite("CaptureDrag 테스트")
struct CaptureDragTests {
    let zelda = captureFixture("a.jpg", at: nil)
    let zeldaVideo = captureFixture("c.mp4", at: nil, kind: .video)
    let mario = captureFixture("b.mp4", game: "마리오 카트 월드", at: nil, kind: .video)

    @Test func `하나를 끌면 놓은 곳에 파일 하나를 둔다`() {
        let drag = CaptureDrag(captures: [zelda], shouldMakeGameFolder: true, naming: .original)
        #expect(drag.name == "a.jpg")
        #expect(drag.fileType == .jpeg)
        #expect(paths(drag.items(at: URL(filePath: "/tmp/놓은 곳/a.jpg"))) == ["/tmp/놓은 곳/a.jpg"])
    }

    @Test func `여러 개를 끌면 한 폴더는 그 폴더 이름으로, 여러 폴더는 Pullshot 폴더 아래 폴더별로 둔다`() {
        let oneGame = CaptureDrag(captures: [zelda, zeldaVideo], shouldMakeGameFolder: true, naming: .original)
        #expect(oneGame.name == "젤다무쌍 봉인전기")
        #expect(paths(oneGame.items(at: URL(filePath: "/tmp/놓은 곳/젤다무쌍 봉인전기"))) == [
            "/tmp/놓은 곳/젤다무쌍 봉인전기/a.jpg",
            "/tmp/놓은 곳/젤다무쌍 봉인전기/c.mp4",
        ])

        let mixed = CaptureDrag(captures: [zelda, mario], shouldMakeGameFolder: true, naming: .original)
        #expect(mixed.name == "Pullshot")
        #expect(paths(mixed.items(at: URL(filePath: "/tmp/놓은 곳/Pullshot"))) == [
            "/tmp/놓은 곳/Pullshot/젤다무쌍 봉인전기/a.jpg",
            "/tmp/놓은 곳/Pullshot/마리오 카트 월드/b.mp4",
        ])
    }

    private func paths(_ items: [TransferItem]) -> [String] {
        items.map { $0.folder.appending(path: $0.filename).path(percentEncoded: false) }
    }
}
