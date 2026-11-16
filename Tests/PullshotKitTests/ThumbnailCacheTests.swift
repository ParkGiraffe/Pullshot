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

    @Test func `크기가 다르면 다른 캡처로 본다`() {
        cache.store(Data([1]), for: CaptureKey(captureFixture("a.jpg", size: 5), serialNumber: "S1"))
        #expect(cache.data(for: CaptureKey(captureFixture("a.jpg", size: 5), serialNumber: "S1")) == Data([1]))
        #expect(cache.data(for: CaptureKey(captureFixture("a.jpg", size: 6), serialNumber: "S1")) == nil)
    }

    @Test func `폴더 밖 캡처와 기타 폴더 캡처를 섞지 않는다`() {
        cache.store(Data([1]), for: CaptureKey(captureFixture("a.jpg", game: nil), serialNumber: "S1"))
        #expect(cache.data(for: CaptureKey(captureFixture("a.jpg", game: nil), serialNumber: "S1")) == Data([1]))
        #expect(cache.data(for: CaptureKey(captureFixture("a.jpg", game: "기타"), serialNumber: "S1")) == nil)
    }

    @Test func `경로로 쓸 수 없는 일련번호면 저장하지 않는다`() {
        let key = CaptureKey(captureFixture("a.jpg"), serialNumber: "../S1")
        cache.store(Data([1]), for: key)
        #expect(cache.data(for: key) == nil)
    }

    @Test func `경로로 쓸 수 없는 게임 폴더면 저장하지 않는다`() {
        let key = CaptureKey(captureFixture("a.jpg", game: "a/b"), serialNumber: "S1")
        cache.store(Data([1]), for: key)
        #expect(cache.data(for: key) == nil)
    }

    @Test func `경로로 쓸 수 없는 파일 이름이면 저장하지 않는다`() {
        let key = CaptureKey(captureFixture("../a.jpg"), serialNumber: "S1")
        cache.store(Data([1]), for: key)
        #expect(cache.data(for: key) == nil)
    }

    @Test func `크기를 모르는 캡처도 저장하고 읽는다`() {
        let key = CaptureKey(captureFixture("a.jpg", size: nil), serialNumber: "S1")
        cache.store(Data([9]), for: key)
        #expect(cache.data(for: key) == Data([9]))
    }
}
