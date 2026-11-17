import Foundation
import PullshotKit

enum ListFormatter {
    static func lines(
        _ scan: AlbumScan,
        isNew: (Capture) -> Bool = { _ in false },
        timeZone: TimeZone
    ) -> [String] {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = timeZone
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        let nameWidth = scan.captures.map(\.filename.count).max() ?? 0
        let sizeWidth = scan.captures.map { sizeText($0).count }.max() ?? 0
        func line(_ capture: Capture) -> String {
            let columns = [
                capture.filename.padding(toLength: nameWidth, withPad: " ", startingAt: 0),
                capture.kind == .photo ? "사진" : "영상",
                String(repeating: " ", count: sizeWidth - sizeText(capture).count) + sizeText(capture),
                capture.capturedAt.map(dateFormatter.string(from:)) ?? "-",
            ]
            return "  " + columns.joined(separator: "  ") + (isNew(capture) ? "  새" : "")
        }

        return Game.games(in: scan.captures).flatMap { game in
            ["\(game.isOther ? "기타" : game.name) (\(game.captures.count))"] + game.captures.map(line)
        }
    }

    private static func sizeText(_ capture: Capture) -> String {
        capture.size.map { String(format: "%.1f MB", Double($0) / 1_000_000) } ?? "-"
    }
}
