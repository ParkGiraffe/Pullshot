import Foundation
import PullshotKit

enum CLIError: Error, Equatable {
    case noConsole
}

/// 오류를 터미널에 보일 문구로 바꿉니다. Kit 타입에는 문구가 없으므로 CLI는 여기 한 곳에서만 바꿉니다.
enum ErrorMessages {
    static func message(for error: Error) -> String {
        switch error {
        case CLIError.noConsole:
            "연결된 스위치가 없습니다. 본체 아래쪽 USB-C 포트에 데이터 케이블로 연결하고, 본체에서 PC로 복사 모드를 켜 주세요."
        // ptpcamerad는 미리보기, 이미지 캡처, 사진 앱이 띄우는 시스템 도우미라 앱 이름 대신 그 앱들을 알려 줍니다.
        case let ConsoleAccessError.heldByAnotherApp(_, owner?) where owner != "ptpcamerad":
            "\(owner) 앱이 스위치를 쓰고 있습니다. 그 앱을 닫고 다시 시도해 주세요."
        case ConsoleAccessError.heldByAnotherApp:
            "다른 앱이 스위치를 쓰고 있습니다. 미리보기, 이미지 캡처, 사진 앱을 닫고 다시 시도해 주세요."
        case ConsoleAccessError.noStillImageInterface, ConsoleAccessError.missingEndpoints:
            "스위치의 사진 전송 기능을 찾지 못했습니다. 본체에서 PC로 복사 모드가 켜져 있는지 확인해 주세요."
        case let ConsoleAccessError.other(code):
            String(format: "스위치에 연결하지 못했습니다(오류 0x%08X).", code)
        case SessionError.transport(.disconnected):
            "스위치 연결이 끊겼습니다. 케이블을 확인하고 다시 시도해 주세요."
        case SessionError.transport(.timedOut):
            "스위치가 응답하지 않습니다. PC로 복사 화면이 켜져 있는지 확인해 주세요."
        case let SessionError.destinationExists(name):
            "이미 같은 이름의 파일이 있습니다: \(name)"
        default:
            "스위치와 통신하지 못했습니다: \(error)"
        }
    }
}
