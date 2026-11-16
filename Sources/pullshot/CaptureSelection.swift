import ArgumentParser
import PullshotKit

/// `pull`과 `export`가 함께 받는 고르기 옵션입니다.
struct SelectionOptions: ParsableArguments {
    @Flag(name: .customLong("all"), help: "모든 캡처를 고릅니다.")
    var isAll = false

    @Flag(name: .customLong("new"), help: "옮긴 적 없는 새 항목만 고릅니다.")
    var isNewOnly = false

    @Argument(help: "고를 캡처입니다. list에 나온 파일 이름이나 \"게임/파일 이름\"입니다.")
    var names: [String] = []

    @Option(help: "이 게임의 캡처만 고릅니다.")
    var game: String?

    func validate() throws {
        guard isAll || isNewOnly || !names.isEmpty else { throw ValidationError("--all, --new, 캡처 이름 중 하나를 주세요.") }
    }

    /// 새 항목은 이 기기의 옮긴 기록에 없는 캡처입니다. 찾지 못한 이름은 표준 오류에 알리고 개수만 돌려줍니다.
    func choose(
        from captures: [Capture],
        ledger: TransferLedger,
        serialNumber: String
    ) -> (chosen: [Capture], missing: Int) {
        let selection = CaptureSelection(names: names, game: game, isNewOnly: isNewOnly)
        let (chosen, missing) = selection.choose(from: captures) {
            !ledger.index.isTransferred($0, serialNumber: serialNumber)
        }
        missing.forEach { Terminal.error("찾지 못한 캡처: \($0)") }
        return (chosen, missing.count)
    }
}

/// 명령줄에서 고른 캡처입니다. `pull`, `export`, `list`가 함께 씁니다.
struct CaptureSelection {
    var names: [String]
    var game: String?
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
