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

    @Suite("메모리")
    struct Memory {
        @Test func `흘려 보낸 바이트를 붙잡아 두지 않는다`() {
            let chunk = Data(count: 512 * 1024)
            let total = 256 * 1024 * 1024
            var header = ByteWriter()
            header.u32(UInt32(ContainerHeader.size + total))
            header.u16(PTP.ContainerKind.data.rawValue)
            header.u16(PTP.Operation.getObject.rawValue)
            header.u32(1)
            var buffer = PacketBuffer()
            buffer.append(header.data)
            _ = buffer.removeFirst(upTo: ContainerHeader.size)
            let peakBefore = Self.peakResidentBytes()
            for _ in 0 ..< total / chunk.count {
                buffer.append(chunk)
                _ = buffer.removeFirst(upTo: chunk.count)
            }

            #expect(Self.peakResidentBytes() - peakBefore < 64 * 1024 * 1024)
        }

        static func peakResidentBytes() -> Int {
            var usage = rusage()
            getrusage(RUSAGE_SELF, &usage)
            return usage.ru_maxrss
        }
    }
}
