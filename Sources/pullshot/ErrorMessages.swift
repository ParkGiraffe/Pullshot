import Foundation
import PullshotKit

enum CLIError: Error, Equatable {
    case noConsole
    case notInTransferMode(String)
}

enum ErrorMessages {
    static func message(for error: Error) -> String {
        switch error {
        case CLIError.noConsole:
            "연결된 스위치가 없습니다. 본체 아래쪽 USB-C 포트에 데이터 케이블로 연결하고, 본체에서 PC로 복사 모드를 켜 주세요."
        case let CLIError.notInTransferMode(name):
            "\(name)가 연결되어 있지만 PC로 복사 모드가 아닙니다. 본체의 설정 > 데이터 관리에서 PC로 복사를 켜 주세요."
        case let error as ConsoleAccessError:
            message(for: error)
        case SessionError.transport(.disconnected):
            "스위치 연결이 끊겼습니다. 케이블을 확인하고 다시 시도해 주세요."
        case SessionError.transport(.timedOut):
            "스위치가 응답하지 않습니다. 본체에서 PC로 복사 모드가 켜져 있는지 확인해 주세요."
        case let SessionError.destinationExists(name):
            "이미 같은 이름의 파일이 있습니다: \(name)"
        case SessionError.needsUSBReset:
            "이전 연결이 남아 있어 스위치의 USB 연결을 재설정했고, 이때 PC로 복사가 꺼졌습니다. 본체에서 PC로 복사를 켠 뒤 다시 실행해 주세요."
        case let SessionError.sizeMismatch(expected, actual):
            "받은 데이터의 크기(\(actual)바이트)가 스위치가 알려 준 크기(\(expected)바이트)와 달라 파일을 저장하지 않았습니다."
        case let FolderMatchError.unreadableFolder(folder):
            "폴더를 열 수 없습니다: \(folder.path(percentEncoded: false)). 경로가 맞는지, 터미널에 그 폴더의 읽기 권한이 있는지 확인해 주세요."
        default:
            fileNotSaved(error) ?? "스위치와 통신하지 못했습니다: \(error)"
        }
    }

    private static func fileNotSaved(_ error: Error) -> String? {
        let path: String?
        switch error {
        case let error as CocoaError where error.isFileError:
            path = error.filePath
        case is POSIXError:
            path = nil
        default:
            return nil
        }
        return path.map { "Mac에 파일을 저장하지 못했습니다: \($0). 폴더가 있는지, 저장 공간이 충분한지, 쓰기 권한이 있는지 확인해 주세요." }
            ?? "Mac에 파일을 저장하지 못했습니다. 저장 위치와 가져온 기록 폴더의 저장 공간이 충분한지, 쓰기 권한이 있는지 확인해 주세요."
    }

    private static func message(for error: ConsoleAccessError) -> String {
        switch error {
        case let .heldByAnotherApp(_, owner?) where owner != "ptpcamerad":
            "\(owner) 앱이 스위치를 사용하고 있습니다. 그 앱을 종료하고 다시 시도해 주세요."
        case .heldByAnotherApp:
            "다른 앱이 스위치를 사용하고 있습니다. 미리보기, 이미지 캡처, 사진 앱을 종료하고 다시 시도해 주세요."
        case .noStillImageInterface, .missingEndpoints:
            "스위치의 사진 전송 기능을 찾지 못했습니다. 본체에서 PC로 복사 모드가 켜져 있는지 확인해 주세요."
        case let .other(code):
            String(format: "스위치에 연결하지 못했습니다(오류 0x%08X).", code)
        }
    }
}
