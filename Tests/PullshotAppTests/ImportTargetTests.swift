import Foundation
import PullshotKit
import Testing
@testable import PullshotApp

@Suite("ImportTarget 테스트")
struct ImportTargetTests {
    /// 찍은 시각을 몰라 번호 뒤에 원래 이름이 붙으므로, 번호 이름이 실행하는 곳의 시간대에 기대지 않습니다.
    let captures = [
        captureFixture("a.jpg", at: nil),
        captureFixture("b.mp4", game: "마리오 카트 월드", at: nil, kind: .video),
    ]
    /// 고른 것 가져오기 규칙을 기본값과 모두 다르게 둡니다.
    let options = ExportOptions(baseFolder: URL(filePath: "/tmp/스위치"), makesGameFolder: false, naming: .numbered)

    @Test func `새 항목과 모두 가져오기는 고른 규칙과 관계없이 저장 위치의 게임 이름 폴더에 원래 이름 그대로 둔다`() {
        for target in [ImportTarget.newItems, .all] {
            #expect(paths(target.items(captures, options: options)) == [
                "/tmp/스위치/젤다무쌍 봉인전기/a.jpg",
                "/tmp/스위치/마리오 카트 월드/b.mp4",
            ], "\(target)")
        }
    }

    @Test func `고른 것 가져오기는 저장 위치 아래에 고른 폴더 나누기와 파일 이름 규칙대로 둔다`() {
        #expect(paths(ImportTarget.selected.items(captures, options: options)) == [
            "/tmp/스위치/001_a.jpg",
            "/tmp/스위치/002_b.mp4",
        ])
    }

    private func paths(_ items: [TransferItem]) -> [String] {
        items.map { $0.folder.appending(path: $0.filename).path(percentEncoded: false) }
    }
}
