import Foundation
import Testing
@testable import PullshotKit

@Suite("Session 내려받기 테스트")
struct SessionDownloadTests {
    static let payload = Data((0 ..< 1500).map { UInt8($0 % 251) })

    static func emptyFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "pullshot-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func contents(of folder: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))
    }

    /// 1,512바이트 데이터 컨테이너를 700, 600, 212바이트로 나눠 보내고 OK로 끝냅니다.
    static func chunkedObject() -> [ScriptedTransport.Step] {
        let whole = dataContainerFixture(.getObject, tid: 1, payload)
        return [
            .expectWrite(Container.command(.getObject, transactionID: 1, parameters: [1]).encoded()),
            .read(whole.prefix(700)), .read(whole.dropFirst(700).prefix(600)), .read(whole.dropFirst(1300)),
            .read(responseFixture(0x2001, tid: 1)),
        ]
    }

    @Suite("성공")
    struct Success {
        @Test func `조각으로 온 원본을 바이트 그대로 저장하고 진행을 늘려 가며 알린다`() throws {
            let folder = try emptyFolder()
            let target = folder.appending(path: "20261114211205_1.jpg")
            var reported: [UInt64] = []

            try Session.openedForTesting(transport: ScriptedTransport(chunkedObject()))
                .download(1, expectedSize: 1500, to: target, progress: { reported.append($0) })

            #expect(try Data(contentsOf: target) == payload)
            #expect(reported.last == 1500)
            #expect(reported == reported.sorted())
            #expect(try contents(of: folder) == ["20261114211205_1.jpg"])
        }

        @Test func `썸네일은 데이터 단계를 그대로 돌려준다`() throws {
            let transport = ScriptedTransport([
                .expectWrite(Container.command(.getThumb, transactionID: 1, parameters: [7]).encoded()),
                .read(dataContainerFixture(.getThumb, tid: 1, Data([0xFF, 0xD8]))),
                .read(responseFixture(0x2001, tid: 1)),
            ])

            #expect(try Session.openedForTesting(transport: transport).thumbnail(7) == Data([0xFF, 0xD8]))
        }
    }

    @Suite("실패")
    struct Failure {
        @Test func `받을 곳에 파일이 있으면 명령을 보내지 않고 덮어쓰지도 않는다`() throws {
            let folder = try emptyFolder()
            let target = folder.appending(path: "a.jpg")
            try Data([1]).write(to: target)
            let transport = ScriptedTransport([])

            #expect(throws: SessionError.destinationExists("a.jpg")) {
                try Session.openedForTesting(transport: transport).download(1, expectedSize: 1, to: target)
            }
            #expect(transport.written.isEmpty)
            #expect(try Data(contentsOf: target) == Data([1]))
        }

        @Test func `받는 중 연결이 끊기면 아무 파일도 남기지 않고 세션을 버린다`() throws {
            let folder = try emptyFolder()
            let whole = dataContainerFixture(.getObject, tid: 1, payload)
            let session = Session.openedForTesting(transport: ScriptedTransport([
                .expectWrite(nil), .read(whole.prefix(700)), .readError(.disconnected),
            ]))

            #expect(throws: SessionError.transport(.disconnected)) {
                try session.download(1, expectedSize: 1500, to: folder.appending(path: "v.mp4"))
            }
            #expect(try contents(of: folder).isEmpty)
            #expect(!session.isValid)
        }

        @Test func `취소하면 아무 파일도 남기지 않고 세션을 버린다`() throws {
            let folder = try emptyFolder()
            let session = Session.openedForTesting(transport: ScriptedTransport(chunkedObject()))
            var checks = 0

            #expect(throws: SessionError.cancelled) {
                try session.download(1, expectedSize: 1500, to: folder.appending(path: "c.jpg"), isCancelled: {
                    checks += 1
                    return checks > 1
                })
            }
            #expect(try contents(of: folder).isEmpty)
            #expect(!session.isValid)
        }

        @Test func `받은 크기가 기기가 알린 크기와 다르면 임시 파일을 지운다`() throws {
            let folder = try emptyFolder()

            #expect(throws: SessionError.sizeMismatch(expected: 2000, actual: 1500)) {
                try Session.openedForTesting(transport: ScriptedTransport(chunkedObject()))
                    .download(1, expectedSize: 2000, to: folder.appending(path: "s.jpg"))
            }
            #expect(try contents(of: folder).isEmpty)
        }

        @Test func `썸네일이 없다는 응답은 오류로 던진다`() {
            let transport = ScriptedTransport([.expectWrite(nil), .read(responseFixture(0x2010, tid: 1))])

            #expect(throws: SessionError.response(.noThumbnailPresent, operation: .getThumb)) {
                try Session.openedForTesting(transport: transport).thumbnail(1)
            }
        }
    }
}
