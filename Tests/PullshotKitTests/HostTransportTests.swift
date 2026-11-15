import Testing
@testable import PullshotKit

@Suite("USB 전송 테스트")
struct HostTransportTests {
    @Suite("엔드포인트 고르기")
    struct Endpoints {
        @Test func `벌크 입력, 벌크 출력, 인터럽트 입력을 주소의 방향 비트로 가른다`() {
            let picked = EndpointSelection.pick([
                EndpointDescriptor(address: 0x81, transferType: .bulk, maxPacketSize: 512),
                EndpointDescriptor(address: 0x02, transferType: .bulk, maxPacketSize: 512),
                EndpointDescriptor(address: 0x83, transferType: .interrupt, maxPacketSize: 8),
            ])

            #expect(picked?.bulkIn == 0x81)
            #expect(picked?.bulkOut == 0x02)
            #expect(picked?.interruptIn == 0x83)
        }

        @Test func `벌크 출력이 없으면 고를 수 없다`() {
            let picked = EndpointSelection.pick([
                EndpointDescriptor(address: 0x81, transferType: .bulk, maxPacketSize: 512),
            ])

            #expect(picked == nil)
        }
    }

    @Suite("전송 오류")
    struct Errors {
        @Test func `파이프 멈춤 코드는 부호가 붙어 와도 멈춤으로 본다`() {
            #expect(TransportError(ioReturn: Int(Int32(bitPattern: 0xE000_5000))) == .stalled)
            #expect(TransportError(ioReturn: 0xE000_5000) == .stalled)
        }

        @Test func `시간 초과와 기기가 사라진 코드를 가른다`() {
            #expect(TransportError(ioReturn: Int(Int32(bitPattern: 0xE000_02D6))) == .timedOut)
            for code: UInt32 in [0xE000_02C0, 0xE000_02D7, 0xE000_02D9, 0xE000_02EB, 0xE000_02ED] {
                #expect(TransportError(ioReturn: Int(Int32(bitPattern: code))) == .disconnected)
            }
        }

        @Test func `그 밖의 코드는 코드를 그대로 담는다`() {
            #expect(TransportError(ioReturn: Int(Int32(bitPattern: 0xE000_02BC))) == .io(code: 0xE000_02BC))
        }
    }
}
