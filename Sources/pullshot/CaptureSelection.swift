import PullshotKit

/// 명령줄에서 고른 캡처입니다. `pull`과 `export`가 함께 씁니다.
struct CaptureSelection {
    var names: [String]
    var game: String?
    var isAll: Bool
    var isNewOnly: Bool

    /// 게임과 새 항목으로 먼저 좁힌 뒤, 이름을 주면 그 이름만 고릅니다. 이름은 파일 이름이나 "게임 폴더/파일 이름"입니다.
    func choose(from captures: [Capture], isNew: (Capture) -> Bool) -> (chosen: [Capture], missing: [String]) {
        let candidates = captures.filter { capture in
            (game.map { capture.gameName == $0 } ?? true) && (!isNewOnly || isNew(capture))
        }
        guard !names.isEmpty else { return (candidates, []) }
        let chosen = candidates.filter { names.contains($0.filename) || names.contains($0.id) }
        let missing = names.filter { name in !chosen.contains { $0.filename == name || $0.id == name } }
        return (chosen, missing)
    }
}
