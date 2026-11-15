import Foundation
import Testing
@testable import PullshotKit

@Suite("Session 트랜잭션 테스트")
struct SessionTransactionTests {
    @Suite("주고받기")
    struct Exchange {
        @Test func `세션 안의 명령은 다음 트랜잭션 ID로 보내고 데이터를 돌려준다`() throws {
            var ids = ByteWriter()
            ids.u32Array([0x0001_0001])
            let transport = ScriptedTransport([
                .expectWrite(Container.command(.getStorageIDs, transactionID: 1).encoded()),
                .read(dataContainerFixture(.getStorageIDs, tid: 1, ids.data)),
                .read(responseFixture(0x2001, tid: 1)),
            ])

            #expect(try Session.openedForTesting(transport: transport).storageIDs() == [0x0001_0001])
            #expect(transport.isFinished)
        }

        @Test func `저장소, 형식, 부모 순서로 객체 핸들을 묻는다`() throws {
            var handles = ByteWriter()
            handles.u32Array([0x10, 0x11])
            let transport = ScriptedTransport([
                .expectWrite(Container.command(
                    .getObjectHandles,
                    transactionID: 1,
                    parameters: [0x0001_0001, 0, PTP.rootParent]
                ).encoded()),
                .read(dataContainerFixture(.getObjectHandles, tid: 1, handles.data)),
                .read(responseFixture(0x2001, tid: 1)),
            ])
            let session = Session.openedForTesting(transport: transport)

            #expect(try session.objectHandles(storage: 0x0001_0001, parent: PTP.rootParent) == [0x10, 0x11])
        }

        @Test func `이벤트 컨테이너와 0바이트 읽기는 건너뛴다`() throws {
            var ids = ByteWriter()
            ids.u32Array([])
            let event = Container(kind: .event, code: 0x4002, transactionID: 0, payload: Data()).encoded()
            let transport = ScriptedTransport([
                .expectWrite(nil), .read(Data()), .read(event),
                .read(dataContainerFixture(.getStorageIDs, tid: 1, ids.data)), .read(Data()),
                .read(responseFixture(0x2001, tid: 1)),
            ])

            #expect(try Session.openedForTesting(transport: transport).storageIDs() == [])
        }
    }

    @Suite("실패")
    struct Failure {
        @Test func `OK가 아닌 응답은 오류로 던지되 세션은 계속 쓸 수 있다`() throws {
            let transport = ScriptedTransport([.expectWrite(nil), .read(responseFixture(0x2009, tid: 1))])
            let session = Session.openedForTesting(transport: transport)

            #expect(throws: SessionError.response(.invalidObjectHandle, operation: .getObjectInfo)) {
                try session.objectInfo(0x42)
            }
            #expect(session.isValid)
        }

        @Test func `응답의 트랜잭션 ID가 다르면 세션을 버린다`() throws {
            let transport = ScriptedTransport([.expectWrite(nil), .read(responseFixture(0x2001, tid: 7))])
            let session = Session.openedForTesting(transport: transport)

            #expect(throws: SessionError.transactionMismatch(expected: 1, got: 7)) { try session.storageIDs() }
            #expect(!session.isValid)
            #expect(throws: SessionError.invalidated) { try session.storageIDs() }
        }

        @Test func `전송이 끊기면 세션을 버린다`() throws {
            let transport = ScriptedTransport([.expectWrite(nil), .readError(.disconnected)])
            let session = Session.openedForTesting(transport: transport)

            #expect(throws: SessionError.transport(.disconnected)) { try session.storageIDs() }
            #expect(!session.isValid)
        }
    }

    @Suite("이상한 기기")
    struct Misbehaving {
        @Test func `빈 읽기만 끝없이 오면 시간 초과로 보고 세션을 버린다`() {
            let transport = ScriptedTransport([.expectWrite(nil)] + Array(repeating: .read(Data()), count: 65))
            let session = Session.openedForTesting(transport: transport)

            #expect(throws: SessionError.transport(.timedOut)) { try session.storageIDs() }
            #expect(!session.isValid)
        }

        @Test func `트랜잭션 ID는 0xFFFFFFFE 다음에 1로 돌아간다`() throws {
            var ids = ByteWriter()
            ids.u32Array([])
            let transport = ScriptedTransport([
                .expectWrite(Container.command(.getStorageIDs, transactionID: 0xFFFF_FFFE).encoded()),
                .read(dataContainerFixture(.getStorageIDs, tid: 0xFFFF_FFFE, ids.data)),
                .read(responseFixture(0x2001, tid: 0xFFFF_FFFE)),
                .expectWrite(Container.command(.getStorageIDs, transactionID: 1).encoded()),
                .read(dataContainerFixture(.getStorageIDs, tid: 1, ids.data)),
                .read(responseFixture(0x2001, tid: 1)),
            ])
            let session = Session.openedForTesting(transport: transport)
            session.nextTransactionID = 0xFFFF_FFFE
            _ = try session.storageIDs()
            _ = try session.storageIDs()

            #expect(transport.isFinished)
        }
    }
}
