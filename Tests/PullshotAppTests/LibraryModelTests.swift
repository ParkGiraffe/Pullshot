import Testing
@testable import PullshotApp

@Suite("LibraryModel 테스트")
@MainActor
struct LibraryModelTests {
    @Suite("끝내기")
    @MainActor
    struct ShuttingDown {
        @Test func `끝내는 중에는 기기를 골라도 열지 않는다`() async throws {
            let model = try libraryModelFixture()
            await model.shutdown()
            model.choose(consoleFixture(1))
            #expect(model.connection == .searching)
        }

        @Test func `끝내는 중에는 처음 연결 질문에 답하지 않는다`() async throws {
            let model = try libraryModelFixture()
            await model.shutdown()
            model.answerFirstConnect(.leaveAllNew)
            #expect(!model.isAnsweringFirstConnect)
        }
    }
}
