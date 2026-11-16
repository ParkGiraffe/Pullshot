import Foundation
import Testing
@testable import PullshotApp
@testable import PullshotKit

/// 테스트 번들에는 문자열 표가 없어 한국어 원문이 그대로 나옵니다.
@Suite("TransferText 테스트")
struct TransferTextTests {
    @Test func `저장 말고는 0개인 칸을 뺀다`() {
        var summary = TransferSummary()
        summary.saved = [URL(filePath: "/tmp/a.jpg")]
        #expect(TransferText.summary(summary) == "저장 1개")
    }

    @Test func `연결이 끊겨 받지 못한 수를 결과에 적는다`() {
        var summary = TransferSummary()
        summary.saved = [URL(filePath: "/tmp/a.jpg")]
        summary.skipped = 2
        summary.failures = [
            TransferFailure(capture: captureFixture("b.jpg"), error: SessionError.transport(.disconnected)),
        ]
        summary.notAttempted = 3
        #expect(TransferText.summary(summary) == "저장 1개 · 건너뜀 2개 · 실패 1개 · 받지 못함 3개")
    }
}
