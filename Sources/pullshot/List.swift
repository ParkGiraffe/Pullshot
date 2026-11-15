import ArgumentParser
import Foundation
import PullshotKit

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "게임별 캡처 목록을 보여 줍니다.")

    @Option(help: "이 게임만 보여 줍니다. 게임 폴더 밖의 캡처는 \"\(ListFormatter.otherGames)\"입니다.")
    var game: String?

    @OptionGroup var connection: ConnectionOptions

    func run() throws {
        try Terminal.run {
            let connection = try Connection.open(connection)
            defer { connection.close() }
            let scan = try AlbumScanner(source: connection.session).scan()
            ListFormatter.lines(Self.only(game, in: scan), timeZone: .current).forEach { print($0) }
            if !scan.skipped.isEmpty {
                Terminal.error("읽지 못했거나 캡처가 아닌 객체 \(scan.skipped.count)개를 건너뛰었습니다.")
            }
        }
    }

    static func only(_ game: String?, in scan: AlbumScan) -> AlbumScan {
        guard let game else { return scan }
        let captures = scan.captures.filter { ($0.gameFolder ?? ListFormatter.otherGames) == game }
        return AlbumScan(captures: captures, skipped: scan.skipped)
    }
}
