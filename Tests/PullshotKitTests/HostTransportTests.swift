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
    }

    @Suite("전송 오류")
    struct Errors {
        @Test(arguments: [
            (0xE000_5000, TransportError.stalled),
            (0xE000_02D6, .timedOut),
            (0xE000_02C0, .disconnected),
            (0xE000_02D7, .disconnected),
            (0xE000_02D9, .disconnected),
            (0xE000_02EB, .disconnected),
            (0xE000_02ED, .disconnected),
            (0xE000_02BC, .io(code: 0xE000_02BC)),
        ] as [(UInt32, TransportError)])
        func `IOKit 코드는 부호가 붙어 와도 멈춤, 시간 초과, 끊김, 그 밖의 오류로 가른다`(
            code: UInt32,
            expected: TransportError
        ) {
            #expect(TransportError(ioReturn: Int(Int32(bitPattern: code))) == expected)
            #expect(TransportError(ioReturn: Int(code)) == expected)
        }
    }
}
