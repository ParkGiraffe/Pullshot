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

        @Test func `실기기로 확인하지 못한 스위치 1만 실험적 지원이다`() {
            #expect(ConsoleModel.switch1.isExperimental)
            #expect(!ConsoleModel.switch2.isExperimental)
        }
    }

    @Suite("접근 오류")
    struct Access {
        @Test func `다른 앱이 잡았을 때 나오는 두 코드는 부호가 붙어 와도 같은 오류다`() {
            for code: UInt32 in [0xE000_02C5, 0xE000_02C9] {
                #expect(ConsoleAccessError(ioReturn: Int(Int32(bitPattern: code))) == .heldByAnotherApp(
                    code: code,
                    owner: nil
                ))
                #expect(ConsoleAccessError(ioReturn: Int(code)) == .heldByAnotherApp(code: code, owner: nil))
            }
        }

        @Test func `인터페이스를 쥔 앱의 이름을 함께 담는다`() {
            let error = ConsoleAccessError(ioReturn: 0xE000_02C5, exclusiveOwner: "pid 38635, Tethersnap")

            #expect(error == .heldByAnotherApp(code: 0xE000_02C5, owner: "Tethersnap"))
        }

        @Test func `그 밖의 코드는 코드를 그대로 담는다`() {
            #expect(ConsoleAccessError(ioReturn: Int(Int32(bitPattern: 0xE000_02BC))) == .other(code: 0xE000_02BC))
        }
    }
}
