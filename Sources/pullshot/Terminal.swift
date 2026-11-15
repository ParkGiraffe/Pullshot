import ArgumentParser
import Foundation
import PullshotKit
import Synchronization

/// Ctrl-C를 받았는지입니다. 신호 처리기는 값을 잡을 수 없어 전역에 둡니다.
private let interruptRequested = Atomic(false)

enum Terminal {
    /// 진단과 오류는 표준 오류에 씁니다. 표준 출력은 목록처럼 다른 도구가 읽을 결과만 둡니다.
    static func error(_ text: String) {
        FileHandle.standardError.write(Data((text + "\n").utf8))
    }

    /// `--verbose`의 한 줄입니다. 시각과 함께 표준 오류에 씁니다.
    static func trace(_ line: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        error("\(formatter.string(from: Date())) \(line)")
    }

    /// 명령 본문을 돌리고, 오류는 문구로 바꿔 표준 오류에 쓴 뒤 종료 코드 1로 끝냅니다.
    static func run(_ body: () throws -> Void) throws {
        do {
            try body()
        } catch let exit as ExitCode {
            throw exit
        } catch SessionError.cancelled {
            Self.error("취소했습니다.")
            throw ExitCode(130)
        } catch {
            Self.error(ErrorMessages.message(for: error))
            throw ExitCode.failure
        }
    }

    /// Ctrl-C를 받으면 바로 끝내지 않고 표시만 합니다. 받던 파일을 지우고 요약을 쓴 뒤에 끝내기 위해서입니다.
    static func listenForInterrupt() {
        signal(SIGINT) { _ in interruptRequested.store(true, ordering: .relaxed) }
    }

    static var isInterrupted: Bool {
        interruptRequested.load(ordering: .relaxed)
    }
}
