import Foundation
import Testing
@testable import PullshotKit

@Suite("받을 곳과 목록 테스트")
struct CLISupportTests {
    static func emptyFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "namer-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    @Suite("받을 곳 정하기")
    struct Destination {
        @Test func `같은 이름이 없으면 그 이름으로 쓴다`() throws {
            let folder = try emptyFolder()

            #expect(DestinationNamer.decide(filename: "a.jpg", size: 3, in: folder)
                == .write(folder.appending(path: "a.jpg")))
        }

        @Test func `같은 이름과 크기의 파일이 있으면 건너뛴다`() throws {
            let folder = try emptyFolder()
            try Data([1, 2, 3]).write(to: folder.appending(path: "a.jpg"))

            #expect(DestinationNamer.decide(filename: "a.jpg", size: 3, in: folder)
                == .skip(folder.appending(path: "a.jpg")))
        }

        @Test func `이름만 같으면 비어 있는 다음 번호를 붙인다`() throws {
            let folder = try emptyFolder()
            try Data([1]).write(to: folder.appending(path: "a.jpg"))
            try Data([1]).write(to: folder.appending(path: "a 2.jpg"))

            #expect(DestinationNamer.decide(filename: "a.jpg", size: 3, in: folder)
                == .write(folder.appending(path: "a 3.jpg")))
        }

        @Test func `크기를 모르면 같은 이름이 있을 때 번호를 붙인다`() throws {
            let folder = try emptyFolder()
            try Data([1]).write(to: folder.appending(path: "a.jpg"))

            #expect(DestinationNamer.decide(filename: "a.jpg", size: nil, in: folder)
                == .write(folder.appending(path: "a 2.jpg")))
        }
    }

    @Suite("목록 쓰기")
    struct Listing {
        static let seoul = TimeZone(identifier: "Asia/Seoul") ?? .gmt

        static func capture(
            _ handle: UInt32,
            _ name: String,
            _ game: String?,
            _ size: UInt64,
            _ stamp: String,
            _ kind: Capture.Kind
        ) -> Capture {
            Capture(
                handle: handle,
                storageID: 1,
                filename: name,
                size: size,
                capturedAt: DateTimeString.parse(stamp, timeZone: seoul),
                kind: kind,
                gameFolder: game
            )
        }

        @Test func `게임을 최근 캡처 순으로 묶고 게임 밖의 캡처는 기타로 끝에 둔다`() {
            let scan = AlbumScan(captures: [
                Self.capture(3, "20261101090000_1.jpg", nil, 400_000, "20261120T090000", .photo),
                Self.capture(2, "20261114211205_1.jpg", "젤다무쌍 봉인전기", 1_100_000, "20261114T211205", .photo),
                Self.capture(1, "20261114211800_1.mp4", "젤다무쌍 봉인전기", 31_200_000, "20261114T211800", .video),
            ], skipped: [])

            #expect(ListFormatter.lines(scan, timeZone: Self.seoul) == [
                "젤다무쌍 봉인전기 (2)",
                "  20261114211800_1.mp4  영상  31.2 MB  2026-11-14 21:18",
                "  20261114211205_1.jpg  사진   1.1 MB  2026-11-14 21:12",
                "기타 (1)",
                "  20261101090000_1.jpg  사진   0.4 MB  2026-11-20 09:00",
            ])
        }

        @Test func `새 항목에는 줄 끝에 새를 붙인다`() {
            let scan = AlbumScan(captures: [captureFixture("2026111421120500_s.jpg")], skipped: [])

            #expect(ListFormatter.lines(scan, isNew: { _ in true }, timeZone: Self.seoul) == [
                "젤다무쌍 봉인전기 (1)",
                "  2026111421120500_s.jpg  사진  0.0 MB  2026-11-14 21:12  새",
            ])
        }

        @Test func `플레이로 보면 플레이 제목 아래에 찍은 순서로 둔다`() {
            let scan = AlbumScan(captures: [
                captureFixture("b.jpg", at: "2026-11-14 21:40:00"),
                captureFixture("a.mp4", at: "2026-11-14 21:12:05", kind: .video),
            ], skipped: [])

            #expect(ListFormatter.lines(scan, showsPlays: true, timeZone: Self.seoul) == [
                "젤다무쌍 봉인전기 (2)",
                "  플레이 2026-11-14 21:12 ~ 21:40 · 사진 1 · 영상 1",
                "    a.mp4  영상  0.0 MB  2026-11-14 21:12",
                "    b.jpg  사진  0.0 MB  2026-11-14 21:40",
            ])
        }

        @Test func `크기나 찍은 시각을 모르면 줄표로 쓴다`() {
            var capture = Self.capture(1, "a.jpg", "Game", 0, "", .photo)
            capture.size = nil

            #expect(ListFormatter.lines(AlbumScan(captures: [capture], skipped: []), timeZone: Self.seoul) == [
                "Game (1)",
                "  a.jpg  사진  -  -",
            ])
        }
    }
}
