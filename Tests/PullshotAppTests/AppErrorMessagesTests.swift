import Foundation
import PullshotKit
import Testing
@testable import PullshotApp

@Suite("AppErrorMessages 테스트")
struct AppErrorMessagesTests {
    @Test func `시스템 사진 도우미가 기기를 잡고 있으면 미리보기와 사진 앱을 종료하라고 한다`() {
        #expect(AppErrorMessages.message(
            for: ConsoleAccessError.heldByAnotherApp(code: 0xE000_02C9, owner: "ptpcamerad")
        ) == "다른 앱이 스위치를 사용하고 있습니다. 미리보기, 이미지 캡처, 사진 앱을 종료하고 다시 시도해 주세요.")
    }

    @Test func `다른 앱이 기기를 잡고 있으면 그 앱 이름을 알려 준다`() {
        #expect(AppErrorMessages.message(
            for: ConsoleAccessError.heldByAnotherApp(code: 0xE000_02C5, owner: "Tethersnap")
        ) == "Tethersnap 앱이 스위치를 사용하고 있습니다. 그 앱을 종료하고 다시 시도해 주세요.")
    }

    @Test func `케이블이 빠지면 연결이 끊겼다고 알린다`() {
        #expect(AppErrorMessages.message(for: SessionError.transport(.disconnected))
            == "스위치 연결이 끊겼습니다. 케이블을 확인해 주세요.")
    }

    @Test(arguments: [
        (
            NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError),
            "Mac에 파일을 저장하지 못했습니다. 저장할 폴더가 있는지, 저장 공간이 충분한지, 쓰기 권한이 있는지 확인해 주세요."
        ),
        (
            NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError),
            "Mac에 파일을 저장하지 못했습니다. 저장할 폴더가 있는지, 저장 공간이 충분한지, 쓰기 권한이 있는지 확인해 주세요."
        ),
        (
            POSIXError(.ENOSPC),
            "Mac에 파일을 저장하지 못했습니다. 저장 위치와 가져온 기록 폴더의 저장 공간이 충분한지, 쓰기 권한이 있는지 확인해 주세요."
        ),
    ] as [(any Error, String)])
    func `디스크가 차거나 저장 위치에 쓰기 권한이 없으면 스위치가 아니라 Mac에 저장하지 못했다고 알린다`(
        error: any Error,
        message: String
    ) {
        #expect(AppErrorMessages.message(for: error) == message)
    }
}
