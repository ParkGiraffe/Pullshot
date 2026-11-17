import Testing
@testable import PullshotKit

@Suite("기기 테스트")
struct ConsoleTests {
    @Suite("기기 모델")
    struct Model {
        @Test func `USB ID로 스위치 2와 스위치 1을 알아본다`() {
            #expect(ConsoleModel.matching(vendorID: 0x057E, productID: 0x2061) == .switch2)
            #expect(ConsoleModel.matching(vendorID: 0x057E, productID: 0x201D) == .switch1)
            #expect(ConsoleModel.matching(vendorID: 0x057E, productID: 0x2000) == nil)
        }

        @Test func `PC로 복사 모드가 아닌 스위치 2도 알아본다`() {
            #expect(ConsoleModel.matchingIdle(vendorID: 0x057E, productID: 0x2060) == .switch2)
            #expect(ConsoleModel.matchingIdle(vendorID: 0x057E, productID: 0x2061) == nil)
        }
    }

    @Suite("접근 오류")
    struct Access {
        @Test(arguments: [
            (0xE000_02C5, ConsoleAccessError.heldByAnotherApp(code: 0xE000_02C5, owner: nil)),
            (0xE000_02C9, .heldByAnotherApp(code: 0xE000_02C9, owner: nil)),
            (0xE000_02BC, .other(code: 0xE000_02BC)),
        ] as [(UInt32, ConsoleAccessError)])
        func `IOKit 코드는 부호가 붙어 와도 다른 앱이 잡은 것과 그 밖의 오류로 가른다`(
            code: UInt32,
            expected: ConsoleAccessError
        ) {
            #expect(ConsoleAccessError(ioReturn: Int(Int32(bitPattern: code))) == expected)
            #expect(ConsoleAccessError(ioReturn: Int(code)) == expected)
        }

        @Test func `인터페이스를 쥔 앱의 이름을 함께 담는다`() {
            let error = ConsoleAccessError(ioReturn: 0xE000_02C5, exclusiveOwner: "pid 38635, Tethersnap")

            #expect(error == .heldByAnotherApp(code: 0xE000_02C5, owner: "Tethersnap"))
        }
    }

    @Suite("기기 감시")
    struct Monitoring {
        @Test(.timeLimit(.minutes(1)))
        func `감시를 놓으면 알림 스트림이 끝난다`() async throws {
            var monitor: ConsoleMonitor? = ConsoleMonitor()
            var changes = try #require(monitor).changes.makeAsyncIterator()
            monitor = nil

            #expect(await changes.next() == nil)
        }
    }
}
