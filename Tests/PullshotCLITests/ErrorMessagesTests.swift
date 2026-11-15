import PullshotKit
import Testing
@testable import pullshot

@Suite("ErrorMessages 테스트")
struct ErrorMessagesTests {
    @Test func `시스템 사진 도우미가 기기를 잡고 있으면 미리보기와 사진 앱을 닫으라고 한다`() {
        let message = "다른 앱이 스위치를 쓰고 있습니다. 미리보기, 이미지 캡처, 사진 앱을 닫고 다시 시도해 주세요."

        #expect(ErrorMessages
            .message(for: ConsoleAccessError.heldByAnotherApp(code: 0xE000_02C9, owner: nil)) == message)
        #expect(ErrorMessages.message(for: ConsoleAccessError.heldByAnotherApp(code: 0xE000_02C9, owner: "ptpcamerad"))
            == message)
    }

    @Test func `다른 앱이 기기를 잡고 있으면 그 앱 이름을 알려 준다`() {
        #expect(ErrorMessages.message(for: ConsoleAccessError.heldByAnotherApp(code: 0xE000_02C5, owner: "Tethersnap"))
            == "Tethersnap 앱이 스위치를 쓰고 있습니다. 그 앱을 닫고 다시 시도해 주세요.")
    }

    @Test func `알 수 없는 접근 오류는 코드를 보여 준다`() {
        #expect(ErrorMessages.message(for: ConsoleAccessError.other(code: 0xE000_02BC))
            == "스위치에 연결하지 못했습니다(오류 0xE00002BC).")
    }

    @Test func `받는 중 케이블을 뽑으면 연결이 끊겼다고 알린다`() {
        #expect(ErrorMessages.message(for: SessionError.transport(.disconnected))
            == "스위치 연결이 끊겼습니다. 케이블을 확인하고 다시 시도해 주세요.")
    }

    @Test func `연결은 됐지만 PC로 복사 모드가 아니면 그 모드를 켜라고 한다`() {
        #expect(ErrorMessages.message(for: CLIError.notInTransferMode("Nintendo Switch 2"))
            == "Nintendo Switch 2가 연결돼 있지만 PC로 복사 모드가 아닙니다. 본체 설정의 데이터 관리에서 PC로 복사를 켜 주세요.")
    }

    @Test func `기기가 없으면 연결 방법을 알려 준다`() {
        #expect(ErrorMessages.message(for: CLIError.noConsole)
            == "연결된 스위치가 없습니다. 본체 아래쪽 USB-C 포트에 데이터 케이블로 연결하고, 본체에서 PC로 복사 모드를 켜 주세요.")
    }
}
