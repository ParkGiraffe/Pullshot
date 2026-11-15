import Foundation
import Testing
@testable import PullshotKit

@Suite("ByteReader, ByteWriter 테스트")
struct ByteCodingTests {
    @Suite("정수")
    struct Integers {
        @Test func `리틀 엔디언으로 8, 16, 32, 64비트 정수를 차례로 읽는다`() throws {
            var reader = ByteReader(Data([
                0x01, 0x34, 0x12, 0x78, 0x56, 0x34, 0x12,
                0xEF, 0xCD, 0xAB, 0x89, 0x67, 0x45, 0x23, 0x01,
            ]))

            #expect(try reader.u8() == 0x01)
            #expect(try reader.u16() == 0x1234)
            #expect(try reader.u32() == 0x1234_5678)
            #expect(try reader.u64() == 0x0123_4567_89AB_CDEF)
            #expect(reader.remaining == 0)
        }

        @Test func `남은 바이트보다 많이 읽으면 필요한 양과 남은 양을 알린다`() {
            var reader = ByteReader(Data([0x01]))

            #expect(throws: PTPDecodingError.truncated(needed: 2, available: 1)) { try reader.u16() }
        }

        @Test func `잘라 낸 Data도 처음부터 읽는다`() throws {
            var reader = ByteReader(Data([0xFF, 0x34, 0x12]).dropFirst())

            #expect(try reader.u16() == 0x1234)
        }
    }

    @Suite("PTP 문자열")
    struct Strings {
        @Test func `글자 수에 종결 문자를 포함하고 UTF-16LE로 쓴다`() {
            var writer = ByteWriter()
            writer.string("AB")
            var empty = ByteWriter()
            empty.string("")

            #expect(writer.data == Data([0x03, 0x41, 0x00, 0x42, 0x00, 0x00, 0x00]))
            #expect(empty.data == Data([0x00]))
        }

        @Test func `한글, 악센트, 보조 평면 문자가 깨지지 않는다`() throws {
            for text in ["젤다무쌍 봉인전기", "Pokémon LEGENDS Z-A", "𝄞 악보", ""] {
                var writer = ByteWriter()
                writer.string(text)
                var reader = ByteReader(writer.data)

                #expect(try reader.string() == text)
            }
        }
    }

    @Suite("배열")
    struct Arrays {
        @Test func `32비트 개수 뒤에 원소를 잇는다`() throws {
            var writer = ByteWriter()
            writer.u16Array([0x1001, 0x100A])
            var reader = ByteReader(writer.data)

            #expect(writer.data == Data([0x02, 0, 0, 0, 0x01, 0x10, 0x0A, 0x10]))
            #expect(try reader.u16Array() == [0x1001, 0x100A])
        }
    }
}
