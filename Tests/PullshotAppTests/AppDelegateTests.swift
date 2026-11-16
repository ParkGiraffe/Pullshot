import Testing
@testable import PullshotApp

@Suite("AppDelegate 테스트")
struct AppDelegateTests {
    @Suite("끝내기 전 정리 기다리기")
    struct Waiting {
        @Test func `정리가 먼저 끝나면 제한 시간까지 기다리지 않는다`() async {
            let elapsed = await ContinuousClock().measure {
                await AppDelegate.wait(for: Task {}, atMost: .seconds(60))
            }
            #expect(elapsed < .seconds(10))
        }

        @Test func `정리가 제한 시간을 넘기면 기다리지 않고 돌아온다`() async {
            let cleanup = Task<Void, Never> { try? await Task.sleep(for: .seconds(60)) }
            let elapsed = await ContinuousClock().measure {
                await AppDelegate.wait(for: cleanup, atMost: .milliseconds(100))
            }
            cleanup.cancel()
            #expect(elapsed < .seconds(10))
        }
    }
}
