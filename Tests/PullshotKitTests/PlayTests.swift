import Foundation
import Testing
@testable import PullshotKit

@Suite("Play 테스트")
struct PlayTests {
    @Suite("나누기")
    struct Splitting {
        @Test func `캡처 사이가 60분을 넘으면 다른 플레이로 나눈다`() {
            let plays = Play.split([
                captureFixture("a.jpg", at: "2026-11-14 21:00:00"),
                captureFixture("d.jpg", at: "2026-11-14 23:30:01"),
                captureFixture("b.jpg", at: "2026-11-14 21:30:00"),
                captureFixture("c.jpg", at: "2026-11-14 22:30:00"),
            ])

            // 22:30에서 23:30:01은 60분 1초라 나누고, 21:30에서 22:30은 꼭 60분이라 잇습니다.
            #expect(plays.map { $0.captures.map(\.filename) } == [["d.jpg"], ["a.jpg", "b.jpg", "c.jpg"]])
            #expect(plays[1].start == dateFixture("2026-11-14 21:00:00"))
            #expect(plays[1].end == dateFixture("2026-11-14 22:30:00"))
        }

        @Test func `찍은 시각을 모르는 캡처는 마지막 플레이 하나로 모은다`() {
            let plays = Play.split([
                captureFixture("x.jpg", at: nil),
                captureFixture("a.jpg"),
                captureFixture("y.jpg", at: nil),
            ])

            #expect(plays.map { $0.captures.map(\.filename) } == [["a.jpg"], ["x.jpg", "y.jpg"]])
            #expect(plays[1].start == nil)
        }
    }

    @Suite("세기")
    struct Counting {
        @Test func `플레이마다 사진과 영상 수를 센다`() {
            let play = Play.split([
                captureFixture("a.jpg"),
                captureFixture("b.mp4", kind: .video),
                captureFixture("c.jpg"),
            ])[0]

            #expect(play.photoCount == 2)
            #expect(play.videoCount == 1)
        }
    }
}
