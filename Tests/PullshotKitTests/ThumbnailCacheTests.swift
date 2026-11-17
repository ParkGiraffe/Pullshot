import Foundation
import Testing
@testable import PullshotKit

@Suite("ThumbnailCache 테스트")
struct ThumbnailCacheTests {
    let cache = ThumbnailCache(directory: temporaryFolderFixture())

    @Test func `저장한 썸네일을 같은 키로 다시 읽는다`() {
        let key = CaptureKey(captureFixture("a.jpg"), serialNumber: "S1")
        cache.store(Data([1, 2, 3]), for: key)
        #expect(cache.data(for: key) == Data([1, 2, 3]))
    }

    @Test(arguments: [
        (captureFixture("a.jpg", size: 5), captureFixture("a.jpg", size: 6)),
        (captureFixture("a.jpg", game: nil), captureFixture("a.jpg", game: "기타")),
    ])
    func `크기가 다르거나 폴더 밖과 기타 폴더로 갈리면 다른 캡처로 본다`(stored: Capture, other: Capture) {
        cache.store(Data([1]), for: CaptureKey(stored, serialNumber: "S1"))
        #expect(cache.data(for: CaptureKey(stored, serialNumber: "S1")) == Data([1]))
        #expect(cache.data(for: CaptureKey(other, serialNumber: "S1")) == nil)
    }

    @Test(arguments: [
        CaptureKey(captureFixture("a.jpg"), serialNumber: "../S1"),
        CaptureKey(captureFixture("a.jpg", game: "a/b"), serialNumber: "S1"),
        CaptureKey(captureFixture("../a.jpg"), serialNumber: "S1"),
    ])
    func `일련번호, 게임 폴더, 파일 이름 가운데 경로로 쓸 수 없는 것이 있으면 저장하지 않는다`(key: CaptureKey) {
        cache.store(Data([1]), for: key)
        #expect(cache.data(for: key) == nil)
    }
}
