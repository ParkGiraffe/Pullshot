import Testing
@testable import PullshotApp

@Suite("ConsoleChoice 테스트")
struct ConsoleChoiceTests {
    @Test func `연 기기가 그대로 꽂혀 있으면 바꾸지 않는다`() {
        #expect(ConsoleChoice.preferring(consoleFixture(1), among: [consoleFixture(2), consoleFixture(1)])
            == consoleFixture(1))
    }

    @Test func `연 기기가 빠지면 남은 기기 중 첫 기기를 고른다`() {
        #expect(ConsoleChoice.preferring(consoleFixture(1), among: [consoleFixture(2)]) == consoleFixture(2))
    }
}
