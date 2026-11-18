import Foundation
import PullshotKit
import Testing
@testable import pullshot

@Suite("ErrorMessages 테스트")
struct ErrorMessagesTests {
    @Test func `시스템 사진 도우미가 기기를 잡고 있으면 미리보기와 사진 앱을 종료하라고 한다`() {
        let message = "다른 앱이 스위치를 사용하고 있습니다. 미리보기, 이미지 캡처, 사진 앱을 종료하고 다시 시도해 주세요."

        #expect(ErrorMessages
            .message(for: ConsoleAccessError.heldByAnotherApp(code: 0xE000_02C9, owner: nil)) == message)
        #expect(ErrorMessages.message(for: ConsoleAccessError.heldByAnotherApp(code: 0xE000_02C9, owner: "ptpcamerad"))
            == message)
    }

    @Test func `다른 앱이 기기를 잡고 있으면 그 앱 이름을 알려 준다`() {
        #expect(ErrorMessages.message(for: ConsoleAccessError.heldByAnotherApp(code: 0xE000_02C5, owner: "Tethersnap"))
            == "Tethersnap 앱이 스위치를 사용하고 있습니다. 그 앱을 종료하고 다시 시도해 주세요.")
    }

    @Test func `받는 중 케이블을 뽑으면 연결이 끊겼다고 알린다`() {
        #expect(ErrorMessages.message(for: SessionError.transport(.disconnected))
            == "스위치 연결이 끊겼습니다. 케이블을 확인하고 다시 시도해 주세요.")
    }

    @Test func `받을 폴더에 쓰지 못하면 스위치가 아니라 Mac에 저장하지 못한 경로를 알린다`() {
        let error = CocoaError(.fileWriteNoPermission, userInfo: [NSFilePathErrorKey: "/Volumes/외장/Pullshot/기타"])

        #expect(ErrorMessages.message(for: error)
            == "Mac에 파일을 저장하지 못했습니다: /Volumes/외장/Pullshot/기타. 폴더가 있는지, 저장 공간이 충분한지, 쓰기 권한이 있는지 확인해 주세요.")
    }

    @Test func `옮긴 기록을 쓰지 못하면 스위치가 아니라 Mac에 저장하지 못했다고 알린다`() {
        #expect(ErrorMessages.message(for: POSIXError(.ENOSPC))
            == "Mac에 파일을 저장하지 못했습니다. 저장 위치와 가져온 기록 폴더의 저장 공간이 충분한지, 쓰기 권한이 있는지 확인해 주세요.")
    }

    @Test func `그 밖의 오류는 스위치와 통신하지 못했다며 원래 오류를 함께 보인다`() {
        #expect(ErrorMessages.message(for: SessionError.invalidated) == "스위치와 통신하지 못했습니다: invalidated")
    }
}
