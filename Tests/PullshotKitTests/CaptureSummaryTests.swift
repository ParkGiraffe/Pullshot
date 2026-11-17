import Foundation
import Testing
@testable import PullshotKit

@Suite("CaptureSummary 테스트")
struct CaptureSummaryTests {
    @Test func `사진과 영상 수, 아는 크기의 합, 처음과 마지막 찍은 때를 센다`() {
        let summary = CaptureSummary([
            captureFixture("a.jpg", at: "2026-11-01 09:00:00", size: 100),
            captureFixture("b.mp4", at: "2026-11-14 23:40:00", size: 300, kind: .video),
            captureFixture("c.jpg", at: nil, size: nil),
        ])

        #expect(summary.photoCount == 2)
        #expect(summary.videoCount == 1)
        #expect(summary.totalSize == 400)
        #expect(summary.first == dateFixture("2026-11-01 09:00:00"))
        #expect(summary.last == dateFixture("2026-11-14 23:40:00"))
    }
}
