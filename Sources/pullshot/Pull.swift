import ArgumentParser
import Foundation
import PullshotKit

struct Pull: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "고른 캡처를 저장 위치로 가져오고 옮긴 기록을 남깁니다. 기본으로 게임 이름 폴더에 원래 이름 그대로 저장합니다."
    )

    @OptionGroup var selection: SelectionOptions

    @Option(help: "저장 위치입니다.")
    var out = Path(argument: TransferItem.defaultImportFolder.path(percentEncoded: false))

    @Flag(name: .customLong("numbered"), help: "찍은 순서대로 번호를 붙입니다. 예: 001_20261114_211205.jpg")
    var isNumbered = false

    @Flag(name: .customLong("no-game-folder"), help: "게임 이름 폴더를 만들지 않고 저장 위치에 바로 둡니다.")
    var shouldSkipGameFolder = false

    @Flag(name: .customLong("dry-run"), help: "가져오지 않고 만들어질 \"폴더/파일 이름\"만 보여 줍니다.")
    var isDryRun = false

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
            let isRenamed = isNumbered || shouldSkipGameFolder
            let items = isRenamed
                ? TransferItem.exports(chosen, options: ExportOptions(
                    baseFolder: out.url,
                    shouldMakeGameFolder: !shouldSkipGameFolder,
                    naming: isNumbered ? .numbered : .original
                ))
                : TransferItem.imports(chosen, into: out.url)
            guard !isDryRun else {
                let basePath = out.url.path(percentEncoded: false) + "/"
                for item in items {
                    let path = item.folder.appending(path: item.filename).path(percentEncoded: false)
                    print(path.replacing(basePath, with: ""))
                }
                return
            }
            let summary = try Transfer(source: connection.session, ledger: ledger, serialNumber: serialNumber).run(
                items,
                as: isRenamed ? .exported : .imported,
                progress: TransferReport.progress,
                isCancelled: { Terminal.isInterrupted }
            )
            try TransferReport.finish(summary, missing: missing, under: out.url)
        }
    }
}
