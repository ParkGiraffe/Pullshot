import ArgumentParser
import Foundation
import PullshotKit
import Synchronization

/// Ctrl-C 요청입니다. 처음에는 정리한 뒤 끝내도록 표시만 하고, 정리가 길어져 한 번 더 누르면 바로 끝냅니다.
final class InterruptRequest: Sendable {
    enum Action {
        case cancel
        case quit
    }

    private let count = Atomic(0)

    var isRequested: Bool {
        count.load(ordering: .relaxed) > 0
    }

    func receive() -> Action {
        count.add(1, ordering: .relaxed).oldValue == 0 ? .cancel : .quit
    }
}

private let interruptRequest = InterruptRequest()
/// Ctrl-C를 지켜보는 디스패치 소스입니다. 프로세스가 끝날 때까지 살아 있어야 해서 전역에 둡니다.
private nonisolated(unsafe) var interruptSource: DispatchSourceSignal?

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
        } catch is CancellationError {
            Self.error("취소했습니다.")
            throw ExitCode(130)
        } catch {
            Self.error(ErrorMessages.message(for: error))
            throw ExitCode.failure
        }
    }

    /// Ctrl-C를 받으면 바로 끝내지 않고 표시만 합니다. 받던 파일을 지우고 세션을 닫은 뒤에 끝내기 위해서입니다.
    /// 신호 처리기를 두면 신호가 진행 중인 USB 읽기를 끊어(0xE00002EB) 세션이 어긋나므로(2026-11-15 확인),
    /// 프로세스는 신호를 무시하고 디스패치 소스로만 알아챕니다. kqueue는 무시한 신호도 알려 줍니다.
    /// 출력을 읽는 쪽이 먼저 끝나도(`list | head`) 세션을 닫기 전에 죽지 않도록 끊긴 파이프 신호도 무시합니다.
    static func listenForInterrupt() {
        signal(SIGINT, SIG_IGN)
        signal(SIGPIPE, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .global())
        source.setEventHandler {
            switch interruptRequest.receive() {
            case .cancel:
                Self.error("취소하는 중입니다. 바로 끝내려면 Ctrl-C를 한 번 더 누르세요.")
            case .quit:
                exit(130)
            }
        }
        source.resume()
        interruptSource = source
    }

    static var isInterrupted: Bool {
        interruptRequest.isRequested
    }
}
