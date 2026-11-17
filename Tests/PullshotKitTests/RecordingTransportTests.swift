import Foundation
import Testing
@testable import PullshotKit

@Suite("전송 기록과 재생 테스트")
struct RecordingTransportTests {
    static func logFile() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "transport-\(UUID()).jsonl")
    }

    @Suite("기록과 재생")
    struct Replaying {
        @Test func `기록한 세션을 재생하면 같은 결과가 나온다`() throws {
            var ids = ByteWriter()
            ids.u32Array([0x0001_0001])
            let file = logFile()
            let live = ScriptedTransport([
                .expectWrite(nil),
                .read(dataContainerFixture(.getStorageIDs, tid: 1, ids.data)),
                .read(responseFixture(0x2001, tid: 1)),
            ])
            let recorded = try Session.openedForTesting(transport: RecordingTransport(wrapping: live, to: file))
                .storageIDs()
            let replay = try ReplayTransport(contentsOf: file)

            #expect(try Session.openedForTesting(transport: replay).storageIDs() == recorded)
            #expect(replay.isFinished)
        }

        @Test func `기록한 전송 오류는 재생에서도 같은 오류로 던진다`() throws {
            let file = logFile()
            let recorder = try RecordingTransport(
                wrapping: ScriptedTransport([.expectWrite(nil), .readError(.timedOut)]),
                to: file
            )
            try recorder.write(Data([1]), timeout: 1)

            #expect(throws: TransportError.timedOut) { try recorder.read(maxLength: 8, timeout: 1) }

            let replay = try ReplayTransport(contentsOf: file)
            try replay.write(Data([1]), timeout: 1)

            #expect(throws: TransportError.timedOut) { try replay.read(maxLength: 8, timeout: 1) }
        }
    }
}
