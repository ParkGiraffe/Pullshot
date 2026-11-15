import Foundation
import Testing
@testable import PullshotKit

@Suite("AlbumScanner 테스트")
struct AlbumScannerTests {
    static let seoul = TimeZone(identifier: "Asia/Seoul") ?? .gmt

    @Suite("게임별로 묶기")
    struct Grouping {
        @Test func `캡처의 게임은 바로 위 폴더 이름이고 루트의 캡처는 게임이 없다`() throws {
            let source = FakeAlbumSource.tree([
                .folder(0x10, "젤다무쌍 봉인전기", [
                    .file(0x11, "20261114211205_1.jpg"),
                    .file(0x12, "20261114211800_1.mp4"),
                ]),
                .folder(0x20, "Mario Kart World", [.file(0x21, "20261105100000_1.jpg")]),
                .file(0x30, "20261101090000_1.jpg"),
            ])
            let captures = try AlbumScanner(source: source, timeZone: seoul).scan().captures

            #expect(captures.map(\.handle) == [0x12, 0x11, 0x21, 0x30])
            #expect(captures.first { $0.handle == 0x12 }?.kind == .video)
            #expect(captures.first { $0.handle == 0x11 }?.gameFolder == "젤다무쌍 봉인전기")
            #expect(captures.first { $0.handle == 0x30 }?.gameFolder == nil)
            #expect(!source.requestedParents.contains(0))
        }

        @Test func `폴더가 겹쳐 있으면 바로 위 폴더를 게임으로 본다`() throws {
            let source = FakeAlbumSource.tree([
                .folder(0x10, "Album", [.folder(0x11, "Splatoon 3", [.file(0x12, "x.jpg")])]),
            ])

            #expect(try AlbumScanner(source: source).scan().captures.map(\.gameFolder) == ["Splatoon 3"])
        }

        @Test func `위험한 폴더 이름 안의 캡처는 게임 없이 둔다`() throws {
            let source = FakeAlbumSource.tree([.folder(0x10, "..", [.file(0x11, "a.jpg")])])

            #expect(try AlbumScanner(source: source).scan().captures.map(\.gameFolder) == [nil])
        }
    }

    @Suite("건너뛰기")
    struct Skipping {
        @Test func `객체 하나를 읽지 못하면 그것만 건너뛴다`() throws {
            let source = FakeAlbumSource.tree([.file(0x11, "a.jpg"), .file(0x12, "b.jpg")])
            source.objectInfoErrors[0x11] = SessionError.response(.invalidObjectHandle, operation: .getObjectInfo)
            let scan = try AlbumScanner(source: source).scan()

            #expect(scan.captures.map(\.handle) == [0x12])
            #expect(scan.skipped == [SkippedObject(handle: 0x11, reason: "response 0x2009")])
        }

        @Test func `전송이 끊기면 훑기를 멈춘다`() {
            let source = FakeAlbumSource.tree([.file(0x11, "a.jpg")])
            source.objectInfoErrors[0x11] = SessionError.transport(.disconnected)

            #expect(throws: SessionError.transport(.disconnected)) { try AlbumScanner(source: source).scan() }
        }

        @Test func `이름을 풀 수 없는 객체는 그것만 건너뛴다`() throws {
            let source = FakeAlbumSource.tree([.file(0x11, "a.jpg"), .file(0x12, "b.jpg")])
            source.objectInfoErrors[0x11] = PTPDecodingError.badString
            let scan = try AlbumScanner(source: source).scan()

            #expect(scan.captures.map(\.handle) == [0x12])
            #expect(scan.skipped == [SkippedObject(handle: 0x11, reason: "badString")])
        }

        @Test func `루트를 읽지 못하는 저장소는 이유와 관계없이 건너뛴다`() throws {
            let source = FakeAlbumSource.tree(
                [.file(0x11, "a.jpg")],
                extraStorage: 0x0002_0001,
                extraStorageError: .response(.accessDenied, operation: .getObjectHandles)
            )

            #expect(try AlbumScanner(source: source).scan().captures.count == 1)
        }

        @Test func `읽을 수 있는 저장소가 하나도 없으면 빈 앨범이 아니라 마지막 응답 오류로 끝난다`() {
            let source = FakeAlbumSource.tree([.file(0x11, "a.jpg")])
            source.storageErrors[FakeAlbumSource.storage] = .response(.deviceBusy, operation: .getObjectHandles)

            #expect(throws: SessionError.response(.deviceBusy, operation: .getObjectHandles)) {
                try AlbumScanner(source: source).scan()
            }
        }

        @Test func `훑는 중에 취소하면 객체 사이에서 멈춘다`() {
            let source = FakeAlbumSource.tree([.file(0x11, "a.jpg"), .file(0x12, "b.jpg"), .file(0x13, "c.jpg")])
            var seen = 0

            #expect(throws: SessionError.cancelled) {
                try AlbumScanner(source: source).scan(progress: { seen = $0 }, isCancelled: { seen >= 2 })
            }
            #expect(seen == 2)
        }

        @Test func `쓸 수 없는 저장소는 건너뛴다`() throws {
            let source = FakeAlbumSource.tree(
                [.file(0x11, "a.jpg")],
                extraStorage: 0x0002_0001,
                extraStorageError: .response(.storeNotAvailable, operation: .getObjectHandles)
            )

            #expect(try AlbumScanner(source: source).scan().captures.count == 1)
        }

        @Test func `받을 폴더 밖을 가리킬 수 있는 파일 이름은 건너뛴다`() throws {
            let names = ["", ".", "..", "a/b.jpg", "x\u{0}.jpg"]
            let source = FakeAlbumSource.tree(names.enumerated().map { .file(UInt32(0x40 + $0.offset), $0.element) })
            let scan = try AlbumScanner(source: source).scan()

            #expect(scan.captures.isEmpty)
            #expect(scan.skipped.count == 5)
            #expect(scan.skipped.allSatisfy { $0.reason == "unsafe filename" })
        }

        @Test func `사진이나 영상이 아닌 파일은 건너뛴다`() throws {
            let source = FakeAlbumSource.tree([.file(0x11, "readme.txt", format: .undefined)])

            let skipped = try AlbumScanner(source: source).scan().skipped

            #expect(skipped == [SkippedObject(handle: 0x11, reason: "not media")])
        }

        @Test func `자기 자신을 다시 가리키는 폴더도 한 번만 훑는다`() throws {
            let source = FakeAlbumSource.tree([.folder(0x10, "Game", [.file(0x11, "a.jpg")])])
            source.makeCycle(at: 0x10)

            #expect(try AlbumScanner(source: source).scan().captures.map(\.handle) == [0x11])
        }
    }

    @Suite("캡처 정보")
    struct Details {
        @Test func `찍은 시각은 기기 정보를 먼저 쓰고 없으면 파일 이름에서 읽는다`() throws {
            let source = FakeAlbumSource.tree([
                .file(0x11, "20200101000000_1.jpg", captureDate: "20261114T211205"),
                .file(0x12, "20261113160500_1.jpg"),
                .file(0x13, "screenshot.jpg"),
            ])
            let captures = try AlbumScanner(source: source, timeZone: seoul).scan().captures
            let byHandle = Dictionary(uniqueKeysWithValues: captures.map { ($0.handle, $0.capturedAt) })

            #expect(byHandle[0x11] == DateTimeString.parse("20261114T211205", timeZone: seoul))
            #expect(byHandle[0x12] == DateTimeString.parse("20261113T160500", timeZone: seoul))
            #expect(byHandle[0x13] == .some(nil))
        }

        @Test func `크기가 모두 1인 비트면 알 수 없음이다`() throws {
            let source = FakeAlbumSource.tree([.file(0x11, "a.jpg", size: 0xFFFF_FFFF)])

            #expect(try AlbumScanner(source: source).scan().captures.first?.size == nil)
        }
    }
}
