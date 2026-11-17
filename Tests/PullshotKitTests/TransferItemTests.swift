import Foundation
import Testing
@testable import PullshotKit

@Suite("TransferItem 테스트")
struct TransferItemTests {
    static let seoul = TimeZone(identifier: "Asia/Seoul") ?? .gmt
    static let numbered = ExportOptions(baseFolder: URL(filePath: "/tmp/blog"), naming: .numbered)

    static func folders(_ items: [TransferItem]) -> [String] {
        items.map { $0.folder.path(percentEncoded: false) }
    }

    @Suite("가져올 곳")
    struct Importing {
        @Test func `가져올 곳은 게임 이름 폴더와 원래 파일 이름이다`() {
            let items = TransferItem.imports(
                [captureFixture("a.jpg"), captureFixture("b.jpg", game: nil)],
                into: URL(filePath: "/p")
            )

            #expect(folders(items) == ["/p/젤다무쌍 봉인전기", "/p/기타"])
            #expect(items.map(\.filename) == ["a.jpg", "b.jpg"])
        }
    }

    @Suite("내보낼 이름")
    struct Exporting {
        @Test func `게임 이름 폴더를 끄면 기준 폴더에 원래 이름으로 둔다`() {
            let options = ExportOptions(baseFolder: URL(filePath: "/tmp/blog"), shouldMakeGameFolder: false)
            let items = TransferItem.exports([captureFixture("a.jpg")], options: options, timeZone: seoul)

            #expect(folders(items) == ["/tmp/blog"])
            #expect(items.map(\.filename) == ["a.jpg"])
        }

        @Test func `번호를 붙이면 찍은 시각 오름차순으로 세 자리부터 센다`() {
            let items = TransferItem.exports([
                captureFixture("2026111423400000_s.jpg", at: "2026-11-14 23:40:00"),
                captureFixture("2026111421120500_s.mp4", at: "2026-11-14 21:12:05", kind: .video),
            ], options: numbered, timeZone: seoul)

            #expect(items.map(\.filename) == ["001_20261114_211205.mp4", "002_20261114_234000.jpg"])
            #expect(folders(items) == ["/tmp/blog/젤다무쌍 봉인전기", "/tmp/blog/젤다무쌍 봉인전기"])
        }

        @Test func `같은 초에 찍은 캡처도 서로 다른 번호를 받는다`() {
            let items = TransferItem.exports([
                captureFixture("2026101122320901_s.jpg", at: "2026-10-11 22:32:09"),
                captureFixture("2026101122320900_s.jpg", at: "2026-10-11 22:32:09"),
            ], options: numbered, timeZone: seoul)

            #expect(items.map(\.capture.filename) == ["2026101122320900_s.jpg", "2026101122320901_s.jpg"])
            #expect(items.map(\.filename) == ["001_20261011_223209.jpg", "002_20261011_223209.jpg"])
        }

        @Test func `천 개면 네 자리로 세고 번호는 게임 폴더마다 따로 센다`() {
            let many = (0 ..< 1000).map { captureFixture("\($0).jpg") }
            let other = [captureFixture("m.jpg", game: "Mario Kart World")]
            let names = TransferItem.exports(many + other, options: numbered, timeZone: seoul).map(\.filename)

            #expect(names.first == "0001_20261114_211205.jpg")
            #expect(names.last == "001_20261114_211205.jpg")
        }

        @Test func `찍은 시각을 모르는 캡처는 번호 뒤에 원래 이름을 붙여 끝에 둔다`() {
            let items = TransferItem.exports(
                [captureFixture("x.jpg", at: nil), captureFixture("a.jpg")],
                options: numbered,
                timeZone: seoul
            )

            #expect(items.map(\.filename) == ["001_20261114_211205.jpg", "002_x.jpg"])
        }
    }
}
