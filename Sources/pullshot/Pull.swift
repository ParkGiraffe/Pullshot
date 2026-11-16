import ArgumentParser
import Foundation
import PullshotKit

struct Pull: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "캡처를 원본 그대로 받습니다. 받을 폴더 아래 게임 이름 폴더에 저장하고 옮긴 기록을 남깁니다."
    )

    @OptionGroup var selection: SelectionOptions

    @Option(help: "받을 폴더입니다.")
    var out = Path(argument: TransferItem.defaultImportFolder.path(percentEncoded: false))

    @OptionGroup var connection: ConnectionOptions
    @OptionGroup var ledgerOptions: LedgerOptions

    func run() throws {
        try Terminal.run {
            let ledger = try ledgerOptions.open()
            let connection = try Connection.open(connection)
            defer { connection.close() }
            let serialNumber = connection.info.serialNumber
            ledger.hintIfFirstConnection(serialNumber: serialNumber)

            let scan = try connection.scanAlbum()
            let (chosen, missing) = selection.choose(from: scan.captures, ledger: ledger, serialNumber: serialNumber)
            let summary = try Transfer(source: connection.session, ledger: ledger, serialNumber: serialNumber).run(
                TransferItem.imports(chosen, into: out.url),
                as: .imported,
                progress: TransferReport.progress,
                isCancelled: { Terminal.isInterrupted }
            )
            try TransferReport.finish(summary, missing: missing, under: out.url)
        }
    }
}
