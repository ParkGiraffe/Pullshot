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

    @Suite("끝난 옮기기 결과")
    @MainActor
    struct FinishedTransfer {
        @Test func `다른 범위를 보면 결과를 닫는다`() async throws {
            let model = try await finishedTransferModelFixture()
            model.show(.new)
            #expect(model.transferRun == nil)
        }

        @Test func `고른 것을 바꾸면 결과를 닫는다`() async throws {
            let model = try await finishedTransferModelFixture()
            var selection = model.selection
            selection.click("젤다무쌍 봉인전기/a.jpg", .only, in: ["젤다무쌍 봉인전기/a.jpg"])
            model.select(selection)
            #expect(model.transferRun == nil)
        }

        @Test func `고른 것과 범위가 그대로면 결과를 남긴다`() async throws {
            let model = try await finishedTransferModelFixture()
            model.select(model.selection)
            model.show(.all)
            #expect(model.transferRun?.isFinished == true)
        }
    }
}

/// 기기 없이 내보내기를 눌러, 열린 세션이 없어 멈춘 결과가 남은 모델입니다.
@MainActor
private func finishedTransferModelFixture() async throws -> LibraryModel {
    let model = try libraryModelFixture()
    model.settings.exportFolder = temporaryFolderFixture()
    model.export()
    while model.isTransferring {
        try await Task.sleep(for: .milliseconds(10))
    }
    try #require(model.transferRun?.isFinished == true)
    return model
}
