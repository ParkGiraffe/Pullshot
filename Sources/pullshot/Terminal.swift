import ArgumentParser
import Foundation
import PullshotKit
import Synchronization

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
private nonisolated(unsafe) var interruptSource: DispatchSourceSignal?

enum Terminal {
    static func error(_ text: String) {
        FileHandle.standardError.write(Data((text + "\n").utf8))
    }

    static func trace(_ line: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        error("\(formatter.string(from: Date())) \(line)")
    }

    static func run(_ body: () throws -> Void) throws {
        listenForInterrupt()
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

    static func listenForInterrupt() {
        signal(SIGINT, SIG_IGN)
        signal(SIGPIPE, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .global())
        source.setEventHandler {
            switch interruptRequest.receive() {
            case .cancel:
                Self.error("취소하는 중입니다. Ctrl-C를 한 번 더 누르면 바로 끝나지만, 다음에 연결할 때 본체에서 PC로 복사를 다시 켜야 할 수 있습니다.")
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
