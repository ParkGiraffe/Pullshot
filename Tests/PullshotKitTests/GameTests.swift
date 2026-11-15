import Foundation
import Testing
@testable import PullshotKit

@Suite("Game 테스트")
struct GameTests {
    @Suite("순서")
    struct Ordering {
        @Test func `게임은 최근 캡처 순이고 시각을 모르는 게임 다음에 기타를 끝에 둔다`() {
            let games = Game.games(in: [
                captureFixture("a.jpg", game: "Mario Kart World", at: "2026-11-05 10:00:00"),
                captureFixture("k.jpg", game: nil, at: "2026-11-20 09:00:00"),
                captureFixture("b.jpg", game: "Pokémon UNITE", at: nil),
                captureFixture("c.jpg", game: "젤다무쌍 봉인전기", at: "2026-11-14 21:00:00"),
            ])

            #expect(games.map(\.name) == ["젤다무쌍 봉인전기", "Mario Kart World", "Pokémon UNITE", "기타"])
        }

        @Test func `게임의 캡처는 최근 것이 먼저다`() {
            let game = Game.games(in: [captureFixture("a.jpg", at: "2026-11-13 16:05:00"), captureFixture("b.jpg")])[0]

            #expect(game.captures.map(\.filename) == ["b.jpg", "a.jpg"])
        }
    }

    @Suite("기타")
    struct Other {
        @Test func `스위치의 기타 폴더와 게임 폴더 밖 캡처를 기타 하나로 묶는다`() {
            let games = Game.games(in: [captureFixture("a.jpg", game: "기타"), captureFixture("b.jpg", game: nil)])

            #expect(games.map(\.name) == ["기타"])
            #expect(games[0].captures.map(\.gameFolder) == ["기타", nil])
        }
    }
}
