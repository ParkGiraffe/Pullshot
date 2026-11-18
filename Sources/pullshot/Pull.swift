import ArgumentParser
import Foundation
import PullshotKit

struct Pull: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "지정한 사진과 동영상을 Mac에 저장하고 가져온 기록에 추가합니다. "
            + "--numbered나 --no-game-folder를 지정하지 않으면 게임 이름 폴더에 원래 이름 그대로 저장합니다."
    )

    @OptionGroup var selection: SelectionOptions

    @Option(help: "저장할 폴더입니다. 앱의 저장 위치 설정은 따르지 않습니다.")
    var out = Path(argument: TransferItem.defaultImportFolder.path(percentEncoded: false))

    @Flag(name: .customLong("numbered"), help: "찍은 순서대로 번호를 붙입니다. 예: 001_20261114_211205.jpg")
    var isNumbered = false

    @Flag(name: .customLong("no-game-folder"), help: "게임 이름 폴더를 만들지 않고 --out 폴더에 바로 저장합니다.")
    var shouldSkipGameFolder = false

    @Flag(name: .customLong("dry-run"), help: "가져오지 않고 저장할 \"폴더/파일 이름\"만 출력합니다.")
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
