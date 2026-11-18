import ArgumentParser
import PullshotKit

struct SelectionOptions: ParsableArguments {
    @Flag(name: .customLong("all"), help: "모든 사진과 동영상을 선택합니다.")
    var isAll = false

    @Flag(name: .customLong("new"), help: "옮긴 적 없는 새 항목만 선택합니다.")
    var isNewOnly = false

    @Argument(help: "가져올 사진과 동영상입니다. list에 나온 파일 이름이나 \"게임/파일 이름\"으로 지정합니다.")
    var names: [String] = []

    @Option(help: "이 게임의 사진과 동영상만 선택합니다.")
    var game: String?

    func validate() throws {
        guard isAll || isNewOnly || !names.isEmpty else { throw ValidationError("--all, --new, 파일 이름 중 하나를 지정해 주세요.") }
    }

    func choose(
        from captures: [Capture],
        ledger: TransferLedger,
        serialNumber: String
    ) -> (chosen: [Capture], missing: Int) {
        let selection = CaptureSelection(names: names, game: game, isNewOnly: isNewOnly)
        let (chosen, missing) = selection.choose(from: captures) {
            !ledger.index.isTransferred($0, serialNumber: serialNumber)
        }
        missing.forEach { Terminal.error("찾지 못한 파일: \($0)") }
        return (chosen, missing.count)
    }
}

struct CaptureSelection {
    var names: [String]
    var game: String?
    var isNewOnly: Bool

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
