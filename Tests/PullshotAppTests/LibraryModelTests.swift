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
            #expect(model.connection == .noConsole)
        }
    }

    @Suite("끝난 옮기기 결과")
    @MainActor
    struct FinishedTransfer {
        @Test func `필터를 바꿔 보이지 않게 된 캡처는 고른 것에서 빼고 결과도 닫는다`() async throws {
            let model = try await finishedTransferModelFixture()
            model.selection.click("젤다무쌍 봉인전기/a.jpg", .only, in: ["젤다무쌍 봉인전기/a.jpg"])
            model.filter(.videos)
            #expect(model.selection.selected.isEmpty)
            #expect(model.transferRun == nil)
        }
    }
}

@MainActor
private func finishedTransferModelFixture() async throws -> LibraryModel {
    let model = try libraryModelFixture()
    model.startImport(.selected)
    while model.isTransferring {
        try await Task.sleep(for: .milliseconds(10))
    }
    try #require(model.transferRun?.isFinished == true)
    return model
}
