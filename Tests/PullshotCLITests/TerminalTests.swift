import ArgumentParser
import Darwin
import Testing
@testable import pullshot

@Suite("Terminal 테스트")
struct TerminalTests {
    @Test func `처음 Ctrl-C는 취소를 요청하고 두 번째는 바로 끝낸다`() {
        let request = InterruptRequest()

        #expect(!request.isRequested)
        #expect(request.receive() == .cancel)
        #expect(request.isRequested)
        #expect(request.receive() == .quit)
    }

    @Test func `폴더 찾기를 취소하면 오류가 아니라 취소로 끝낸다`() {
        #expect(throws: ExitCode(130)) { try Terminal.run { throw CancellationError() } }
    }

    @Test func `Ctrl-C를 기다리는 명령은 읽는 쪽이 먼저 끝나도 세션을 닫기 전에 죽지 않는다`() {
        Terminal.listenForInterrupt()
        var action = sigaction()
        sigaction(SIGPIPE, nil, &action)

        #expect(unsafeBitCast(action.__sigaction_u.__sa_handler, to: Int.self) == unsafeBitCast(SIG_IGN, to: Int.self))
    }
}
