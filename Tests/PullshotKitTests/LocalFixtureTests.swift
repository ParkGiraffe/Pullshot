import Foundation
import Testing
@testable import PullshotKit

private let transcript = URL(filePath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appending(path: "LocalFixtures/switch2-23.5.0/transcript.jsonl")

@Suite(
    "실기기 기록 재생 테스트",
    .enabled(if: FileManager.default.fileExists(atPath: transcript.path(percentEncoded: false)))
)
struct LocalFixtureTests {
    @Test func `스위치 2 앨범을 열고 훑으면 모든 캡처를 건너뛰지 않고 읽는다`() throws {
        let session = try Session(transport: ReplayTransport(contentsOf: transcript))

        #expect(try session.open().model == "Nintendo Switch 2")
        for storage in try session.storageIDs() {
            _ = try session.storageInfo(storage)
        }
        let scan = try AlbumScanner(source: session).scan()

        #expect(!scan.captures.isEmpty)
        #expect(scan.captures.allSatisfy { Capture.isSafeFilename($0.filename) })
        #expect(scan.skipped.isEmpty)
    }
}
