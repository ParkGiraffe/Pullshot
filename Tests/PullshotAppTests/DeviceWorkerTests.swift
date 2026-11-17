import Foundation
import Testing
@testable import PullshotApp

@Suite("DeviceWorker 테스트")
struct DeviceWorkerTests {
    @Suite("받아 둔 미리보기 원본")
    struct PreviewOriginal {
        @Test func `크기가 같은 파일이 있으면 다시 받지 않는다`() throws {
            let file = try previewFileFixture(bytes: 5)
            #expect(DeviceWorker.hasPreview(of: captureFixture(size: 5), at: file))
        }

        @Test func `받아 둔 파일이 지워졌으면 다시 받는다`() throws {
            let file = try previewFileFixture(bytes: 5)
            try FileManager.default.removeItem(at: file)
            #expect(!DeviceWorker.hasPreview(of: captureFixture(size: 5), at: file))
        }

        @Test func `크기가 다른 파일이면 다시 받는다`() throws {
            let file = try previewFileFixture(bytes: 3)
            #expect(!DeviceWorker.hasPreview(of: captureFixture(size: 5), at: file))
        }

        @Test func `크기를 모르는 캡처는 늘 다시 받는다`() throws {
            let file = try previewFileFixture(bytes: 5)
            #expect(!DeviceWorker.hasPreview(of: captureFixture(size: nil), at: file))
        }
    }
}

/// 임시 폴더에 만든 `bytes` 바이트짜리 파일입니다.
private func previewFileFixture(bytes: Int) throws -> URL {
    let folder = temporaryFolderFixture()
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let file = folder.appending(path: "2026111421120500_s.jpg")
    try Data(count: bytes).write(to: file)
    return file
}
