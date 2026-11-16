import Foundation
import PullshotKit
import Testing
@testable import PullshotApp

/// 테스트 번들에는 문자열 표가 없어 한국어 원문이 그대로 나옵니다.
@Suite("AppErrorMessages 테스트")
struct AppErrorMessagesTests {
    @Test func `시스템 사진 도우미가 기기를 잡고 있으면 미리보기와 사진 앱을 종료하라고 한다`() {
        #expect(AppErrorMessages.message(
            for: ConsoleAccessError.heldByAnotherApp(code: 0xE000_02C9, owner: "ptpcamerad")
        ) == "다른 앱이 스위치를 쓰고 있습니다. 미리보기, 이미지 캡처, 사진 앱을 종료하고 다시 시도해 주세요.")
    }

    @Test func `다른 앱이 기기를 잡고 있으면 그 앱 이름을 알려 준다`() {
        #expect(AppErrorMessages.message(
            for: ConsoleAccessError.heldByAnotherApp(code: 0xE000_02C5, owner: "Tethersnap")
        ) == "Tethersnap 앱이 스위치를 쓰고 있습니다. 그 앱을 종료하고 다시 시도해 주세요.")
    }

    @Test func `케이블이 빠지면 연결이 끊겼다고 알린다`() {
        #expect(AppErrorMessages.message(for: SessionError.transport(.disconnected))
            == "스위치 연결이 끊겼습니다. 케이블을 확인해 주세요.")
    }

    @Test func `알 수 없는 접근 오류는 코드를 보여 준다`() {
        #expect(AppErrorMessages.message(for: ConsoleAccessError.other(code: 0xE000_02BC))
            == "스위치에 연결하지 못했습니다(오류 0xE00002BC).")
    }

    @Test func `찾을 폴더를 열 수 없으면 폴더 이름과 권한을 알려 준다`() {
        #expect(AppErrorMessages.message(for: FolderMatchError.unreadableFolder(URL(filePath: "/tmp/없는 폴더")))
            == "폴더를 열 수 없습니다: 없는 폴더. 폴더가 있는지, 읽을 권한이 있는지 확인해 주세요.")
    }

    /// Foundation은 받을 파일과 폴더의 쓰기 오류를 `NSCocoaErrorDomain`의 NSError로 던집니다(2026-11-16, macOS 27.2 확인).
    @Test func `디스크가 차서 받은 파일을 쓰지 못하면 Mac에 저장하지 못했다고 알린다`() {
        #expect(AppErrorMessages.message(for: NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError))
            == "Mac에 파일을 저장하지 못했습니다. 저장할 폴더가 있는지, 저장 공간이 충분한지, 쓰기 권한이 있는지 확인해 주세요.")
    }

    @Test func `내보낼 폴더에 쓰기 권한이 없으면 Mac에 저장하지 못했다고 알린다`() {
        #expect(AppErrorMessages.message(for: NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError))
            == "Mac에 파일을 저장하지 못했습니다. 저장할 폴더가 있는지, 저장 공간이 충분한지, 쓰기 권한이 있는지 확인해 주세요.")
    }

    /// 옮긴 기록은 `TransferLedger`가 errno를 담은 `POSIXError`로 던집니다.
    @Test func `옮긴 기록을 쓸 공간이 없어도 Mac에 저장하지 못했다고 알린다`() {
        #expect(AppErrorMessages.message(for: POSIXError(.ENOSPC))
            == "Mac에 파일을 저장하지 못했습니다. 저장할 폴더가 있는지, 저장 공간이 충분한지, 쓰기 권한이 있는지 확인해 주세요.")
    }
}
