import ArgumentParser
import Foundation
import PullshotKit

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "게임별 사진과 동영상 목록을 출력합니다. 새 항목은 줄 끝에 \"새 항목\"이라고 표시합니다.")

    @Option(help: "이 게임의 사진과 동영상만 출력합니다. 게임 폴더 밖의 사진과 동영상은 \"\(Game.otherFolderName)\"로 지정합니다.")
    var game: String?

    @Flag(name: .customLong("new"), help: "옮긴 적 없는 새 항목만 출력합니다.")
    var isNewOnly = false

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
            let isNew = { (capture: Capture) in !ledger.index.isTransferred(capture, serialNumber: serialNumber) }
            let selection = CaptureSelection(names: [], game: game, isNewOnly: isNewOnly)
            let chosen = selection.choose(from: scan.captures, isNew: isNew).chosen
            let shown = AlbumScan(captures: chosen, skipped: scan.skipped)
            ListFormatter.lines(shown, isNew: isNew, timeZone: .current).forEach { print($0) }
            if !scan.skipped.isEmpty {
                Terminal.error("읽지 못했거나 사진과 동영상이 아닌 객체 \(scan.skipped.count)개를 건너뛰었습니다.")
            }
        }
    }
}
