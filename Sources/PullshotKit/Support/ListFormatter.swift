import Foundation

/// 훑은 앨범을 게임별 목록 글로 씁니다. CLI의 `list`와 `dump`가 씁니다.
public enum ListFormatter {
    /// 게임은 가장 최근 캡처 순, 기타는 끝입니다. 칸은 공백 두 칸으로 나누고,
    /// 파일 이름은 왼쪽, 크기는 오른쪽에 맞춥니다.
    public static func lines(_ scan: AlbumScan, timeZone: TimeZone) -> [String] {
        let groups = Dictionary(grouping: scan.captures.sorted(by: Capture.newestFirst), by: \.gameFolder)
            .sorted { lhs, rhs in
                guard (lhs.key == nil) == (rhs.key == nil) else { return rhs.key == nil }
                return Capture.newestFirst(lhs.value[0], rhs.value[0])
            }
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = timeZone
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        let nameWidth = scan.captures.map(\.filename.count).max() ?? 0
        let sizeWidth = scan.captures.map { sizeText($0).count }.max() ?? 0

        return groups.flatMap { game, captures in
            ["\(game ?? Game.otherName) (\(captures.count))"] + captures.map { capture in
                "  " + [
                    capture.filename.padding(toLength: nameWidth, withPad: " ", startingAt: 0),
                    capture.kind == .photo ? "사진" : "영상",
                    String(repeating: " ", count: sizeWidth - sizeText(capture).count) + sizeText(capture),
                    capture.capturedAt.map(dateFormatter.string(from:)) ?? "-",
                ].joined(separator: "  ")
            }
        }
    }

    /// 1 MB는 1,000,000바이트입니다.
    private static func sizeText(_ capture: Capture) -> String {
        capture.size.map { String(format: "%.1f MB", Double($0) / 1_000_000) } ?? "-"
    }
}
