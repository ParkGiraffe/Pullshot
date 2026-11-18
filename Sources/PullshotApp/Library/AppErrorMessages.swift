import Foundation
import PullshotKit

enum AppErrorMessages {
    static func message(for error: any Error) -> String {
        switch error {
        case let error as ConsoleAccessError:
            message(for: error)
        case SessionError.transport(.disconnected):
            String(localized: "스위치 연결이 끊겼습니다. 케이블을 확인해 주세요.")
        case SessionError.transport(.timedOut):
            String(localized: "스위치가 응답하지 않습니다. 본체에서 PC로 복사 모드가 켜져 있는지 확인해 주세요.")
        case let SessionError.destinationExists(name):
            String(localized: "이미 같은 이름의 파일이 있습니다: \(name)")
        case SessionError.sizeMismatch:
            String(localized: "받은 데이터의 크기가 스위치가 알려 준 크기와 달라 파일을 저장하지 않았습니다.")
        case SessionError.cancelled, is CancellationError:
            String(localized: "취소했습니다.")
        case let FolderMatchError.unreadableFolder(folder):
            String(localized: "폴더를 열 수 없습니다: \(folder.lastPathComponent). 폴더가 있는지, 읽기 권한이 있는지 확인해 주세요.")
        case let error as CocoaError where error.isFileError:
            String(localized: "Mac에 파일을 저장하지 못했습니다. 저장할 폴더가 있는지, 저장 공간이 충분한지, 쓰기 권한이 있는지 확인해 주세요.")
        case is POSIXError:
            String(localized: "Mac에 파일을 저장하지 못했습니다. 저장 위치와 가져온 기록 폴더의 저장 공간이 충분한지, 쓰기 권한이 있는지 확인해 주세요.")
        default:
            String(localized: "스위치와 통신하지 못했습니다. 도움말 메뉴의 로그 파일 보기에서 자세한 내용을 확인할 수 있습니다.")
        }
    }

    private static func message(for error: ConsoleAccessError) -> String {
        switch error {
        case let .heldByAnotherApp(_, owner?) where owner != "ptpcamerad":
            String(localized: "\(owner) 앱이 스위치를 사용하고 있습니다. 그 앱을 종료하고 다시 시도해 주세요.")
        case .heldByAnotherApp:
            String(localized: "다른 앱이 스위치를 사용하고 있습니다. 미리보기, 이미지 캡처, 사진 앱을 종료하고 다시 시도해 주세요.")
        case .noStillImageInterface, .missingEndpoints:
            String(localized: "스위치의 사진 전송 기능을 찾지 못했습니다. 본체에서 PC로 복사 모드가 켜져 있는지 확인해 주세요.")
        case let .other(code):
            String(localized: "스위치에 연결하지 못했습니다(오류 \(String(format: "0x%08X", code))).")
        }
    }
}
