import ArgumentParser
import Foundation
import PullshotKit

struct Export: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "고른 캡처를 기준 폴더로 내보냅니다. 기본으로 그 아래 게임 이름 폴더를 만들고 옮긴 기록을 남깁니다."
    )

    @Flag(help: "모든 캡처를 내보냅니다.")
    var all = false

    @Flag(name: .customLong("new"), help: "옮긴 적 없는 새 항목만 내보냅니다.")
    var isNewOnly = false

    @Argument(help: "내보낼 캡처입니다. list에 나온 파일 이름이나 \"게임/파일 이름\"입니다.")
    var names: [String] = []

    @Option(help: "이 게임의 캡처만 내보냅니다.")
    var game: String?

    @Option(help: "내보낼 기준 폴더입니다.")
    var out: String

    @Flag(name: .customLong("numbered"), help: "찍은 순서대로 번호를 붙입니다. 예: 001_20261114_211205.jpg")
    var isNumbered = false

    @Flag(name: .customLong("no-game-folder"), help: "게임 이름 폴더를 만들지 않고 기준 폴더에 바로 둡니다.")
    var skipsGameFolder = false

    @Flag(name: .customLong("dry-run"), help: "내보내지 않고 만들어질 \"폴더/파일 이름\"만 보여 줍니다.")
    var isDryRun = false

    @OptionGroup var connection: ConnectionOptions
    @OptionGroup var ledgerOptions: LedgerOptions

    func validate() throws {
        guard all || isNewOnly || !names.isEmpty else {
            throw ValidationError("--all, --new, 내보낼 캡처 이름 중 하나를 주세요.")
        }
    }

    func run() throws {
        try Terminal.run {
            Terminal.listenForInterrupt()
            let ledger = try ledgerOptions.open()
            let connection = try Connection.open(connection)
            defer { connection.close() }
            let serialNumber = connection.info.serialNumber
            ledger.hintIfFirstConnection(serialNumber: serialNumber)

            let scan = try AlbumScanner(source: connection.session).scan(isCancelled: { Terminal.isInterrupted })
            let selection = CaptureSelection(names: names, game: game, isAll: all, isNewOnly: isNewOnly)
            let (chosen, missing) = selection.choose(from: scan.captures) {
                !ledger.isTransferred($0, serialNumber: serialNumber)
            }
            missing.forEach { Terminal.error("찾지 못한 캡처: \($0)") }
            let base = URL(filePath: (out as NSString).expandingTildeInPath)
            let options = ExportOptions(
                baseFolder: base,
                makesGameFolder: !skipsGameFolder,
                naming: isNumbered ? .numbered : .original
            )
            let items = TransferItem.exports(chosen, options: options)
            guard !isDryRun else {
                // 같은 이름의 파일이 이미 있으면 실제로는 "이름 2.확장자"로 저장될 수 있습니다.
                let basePath = base.path(percentEncoded: false) + "/"
                for item in items {
                    let path = item.folder.appending(path: item.filename).path(percentEncoded: false)
                    print(path.replacing(basePath, with: ""))
                }
                return
            }
            let summary = try Transfer(source: connection.session, ledger: ledger, serialNumber: serialNumber).run(
                items,
                as: .exported,
                progress: TransferReport.progress,
                isCancelled: { Terminal.isInterrupted }
            )
            try TransferReport.finish(summary, missing: missing.count, under: base)
        }
    }
}
