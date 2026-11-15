import Foundation
import Testing
@testable import PullshotKit

@Suite("PacketBuffer 테스트")
struct PacketBufferTests {
    static let storageIDs = Container(
        kind: .data,
        code: 0x1004,
        transactionID: 1,
        payload: Data([1, 0, 0, 0, 1, 0, 1, 0])
    ).encoded()
    static let ok = Container(kind: .response, code: 0x2001, transactionID: 1, payload: Data()).encoded()

    @Suite("컨테이너 꺼내기")
    struct Extracting {
        @Test func `컨테이너가 여러 조각으로 오면 나머지가 올 때까지 기다린다`() throws {
            var buffer = PacketBuffer()
            buffer.append(storageIDs.prefix(5))

            #expect(try buffer.nextContainer() == nil)

            buffer.append(storageIDs.dropFirst(5))

            #expect(try buffer.nextContainer()?.code == 0x1004)
        }

        @Test func `한 조각에 붙어 온 컨테이너를 순서대로 꺼낸다`() throws {
            var buffer = PacketBuffer()
            buffer.append(storageIDs + ok)

            #expect(try buffer.nextContainer()?.kind == .data)
            #expect(try buffer.nextContainer()?.kind == .response)
            #expect(buffer.isEmpty)
        }

        @Test func `0바이트 조각은 아무것도 바꾸지 않는다`() throws {
            var buffer = PacketBuffer()
            buffer.append(Data())

            #expect(buffer.isEmpty)
            #expect(try buffer.peekHeader() == nil)
        }
    }

    @Suite("흘려 읽기")
    struct Streaming {
        @Test func `데이터 페이로드만 덜어 내면 뒤의 응답이 남는다`() throws {
            var buffer = PacketBuffer()
            buffer.append(storageIDs + ok)
            let header = try #require(try buffer.peekHeader())
            _ = buffer.removeFirst(upTo: ContainerHeader.size)
            let payload = buffer.removeFirst(upTo: Int(header.length) - ContainerHeader.size)

            #expect(payload.count == 8)
            #expect(try buffer.nextContainer()?.code == 0x2001)
        }
    }
}
