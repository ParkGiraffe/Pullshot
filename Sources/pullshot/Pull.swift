import ArgumentParser
import Foundation
import PullshotKit

struct Pull: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "캡처를 원본 그대로 받습니다. 받을 폴더 아래 게임 이름 폴더에 저장하고 옮긴 기록을 남깁니다."
    )

    @Flag(help: "모든 캡처를 받습니다.")
    var all = false

    @Flag(name: .customLong("new"), help: "옮긴 적 없는 새 항목만 받습니다.")
    var isNewOnly = false

    @Argument(help: "받을 캡처입니다. list에 나온 파일 이름이나 \"게임/파일 이름\"입니다.")
    var names: [String] = []

    @Option(help: "이 게임의 캡처만 받습니다.")
    var game: String?

    @Option(help: "받을 폴더입니다.")
    var out = TransferItem.defaultImportFolder.path(percentEncoded: false)

    @OptionGroup var connection: ConnectionOptions
    @OptionGroup var ledgerOptions: LedgerOptions

    func validate() throws {
        guard all || isNewOnly || !names.isEmpty else { throw ValidationError("--all, --new, 받을 캡처 이름 중 하나를 주세요.") }
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
            let root = URL(filePath: (out as NSString).expandingTildeInPath)
            let summary = try Transfer(source: connection.session, ledger: ledger, serialNumber: serialNumber).run(
                TransferItem.imports(chosen, into: root),
                as: .imported,
                progress: TransferReport.progress,
                isCancelled: { Terminal.isInterrupted }
            )
            try TransferReport.finish(summary, missing: missing.count, under: root)
        }
    }
}
