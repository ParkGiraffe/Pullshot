import Foundation
import Testing
@testable import PullshotKit

@Suite("Container 테스트")
struct ContainerTests {
    @Suite("명령 만들기")
    struct Command {
        @Test func `명령 컨테이너는 길이, 종류, 코드, 트랜잭션 ID, 인자 순서로 쓴다`() {
            let container = Container.command(.openSession, transactionID: 0, parameters: [1])

            #expect(container.encoded() == Data([
                0x10, 0, 0, 0, 0x01, 0x00, 0x02, 0x10,
                0, 0, 0, 0, 0x01, 0, 0, 0,
            ]))
        }

        @Test func `스위치가 응답하는 기본 명령은 0x1001부터 0x100A까지 열 개다`() {
            #expect(PTP.Operation.baseline.map(\.rawValue) == Array(0x1001 ... 0x100A))
        }
    }

    @Suite("헤더 읽기")
    struct Header {
        @Test func `길이, 종류, 코드, 트랜잭션 ID를 읽는다`() throws {
            let header = try ContainerHeader(Data([0x0C, 0, 0, 0, 0x03, 0x00, 0x01, 0x20, 0x05, 0, 0, 0]))

            #expect(header == ContainerHeader(length: 12, kind: .response, code: 0x2001, transactionID: 5))
        }

        @Test func `헤더보다 짧은 길이와 모르는 종류는 거부한다`() {
            #expect(throws: PTPDecodingError.badContainerLength(8)) {
                try ContainerHeader(Data([8, 0, 0, 0, 3, 0, 0x01, 0x20, 0, 0, 0, 0]))
            }
            #expect(throws: PTPDecodingError.unknownContainerKind(9)) {
                try ContainerHeader(Data([12, 0, 0, 0, 9, 0, 0x01, 0x20, 0, 0, 0, 0]))
            }
        }
    }

    @Suite("응답 인자")
    struct Parameters {
        @Test func `응답 페이로드를 32비트 인자 목록으로 읽는다`() {
            var payload = ByteWriter()
            payload.u32(7)
            payload.u32(9)
            let container = Container(kind: .response, code: 0x2001, transactionID: 1, payload: payload.data)

            #expect(container.parameters == [7, 9])
        }
    }
}
