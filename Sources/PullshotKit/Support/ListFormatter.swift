import Foundation

/// 훑은 앨범을 게임별 목록 글로 씁니다. CLI의 `list`와 `dump`가 씁니다.
public enum ListFormatter {
    /// 게임은 가장 최근 캡처 순, 기타는 끝입니다(`Game.games`). 칸은 공백 두 칸으로 나누고,
    /// 파일 이름은 왼쪽, 크기는 오른쪽에 맞춥니다. 새 항목은 줄 끝에 "새"를 붙이고,
    /// 플레이로 보면 플레이 제목 아래에 찍은 순서로 둡니다.
    public static func lines(
        _ scan: AlbumScan,
        isNew: (Capture) -> Bool = { _ in false },
        showsPlays: Bool = false,
        timeZone: TimeZone
    ) -> [String] {
        let dateFormatter = formatter("yyyy-MM-dd HH:mm", timeZone: timeZone)
        let timeFormatter = formatter("HH:mm", timeZone: timeZone)
        let nameWidth = scan.captures.map(\.filename.count).max() ?? 0
        let sizeWidth = scan.captures.map { sizeText($0).count }.max() ?? 0
        func line(_ capture: Capture, indent: String) -> String {
            indent + [
                capture.filename.padding(toLength: nameWidth, withPad: " ", startingAt: 0),
                capture.kind == .photo ? "사진" : "영상",
                String(repeating: " ", count: sizeWidth - sizeText(capture).count) + sizeText(capture),
                capture.capturedAt.map(dateFormatter.string(from:)) ?? "-",
            ].joined(separator: "  ") + (isNew(capture) ? "  새" : "")
        }

        return Game.games(in: scan.captures).flatMap { game in
            let header = "\(game.name) (\(game.captures.count))"
            guard showsPlays else { return [header] + game.captures.map { line($0, indent: "  ") } }
            return [header] + game.plays.flatMap { play in
                ["  " + playTitle(play, date: dateFormatter, time: timeFormatter)]
                    + play.captures.map { line($0, indent: "    ") }
            }
        }
    }

    /// `플레이 <시작> ~ <끝 시각> · 사진 N · 영상 N`이고, 0개인 종류는 뺍니다.
    private static func playTitle(_ play: Play, date: DateFormatter, time: DateFormatter) -> String {
        let period = if let start = play.start, let end = play.end {
            "\(date.string(from: start)) ~ \(time.string(from: end))"
        } else {
            "시각 모름"
        }
        let counts = [("사진", play.photoCount), ("영상", play.videoCount)].filter { $0.1 > 0 }.map { "\($0.0) \($0.1)" }
        return (["플레이 \(period)"] + counts).joined(separator: " · ")
    }

    private static func formatter(_ format: String, timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter
    }

    /// 1 MB는 1,000,000바이트입니다.
    private static func sizeText(_ capture: Capture) -> String {
        capture.size.map { String(format: "%.1f MB", Double($0) / 1_000_000) } ?? "-"
    }
}
