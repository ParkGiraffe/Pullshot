import ArgumentParser
import Foundation
import PullshotKit

struct Ledger: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "처음 연결 질문에 답합니다. 이미 받아 둔 캡처를 옮긴 기록에 넣어 새 항목에서 뺍니다."
    )

    @Option(
        name: .customLong("from-folder"),
        help: "이 폴더 아래 어디에 있든 파일 이름과 크기가 같은 캡처를 옮긴 것으로 기록합니다."
    )
    var folder: Path?

    @Flag(name: .customLong("mark-all"), help: "지금 있는 캡처를 모두 옮긴 것으로 기록합니다.")
    var marksAll = false

    @Flag(name: .customLong("leave-new"), help: "기록하지 않고 모두 새 항목으로 둡니다. 다시 묻지 않습니다.")
    var leavesNew = false

    @OptionGroup var connection: ConnectionOptions
    @OptionGroup var ledgerOptions: LedgerOptions

    func validate() throws {
        guard [folder != nil, marksAll, leavesNew].count(where: { $0 }) == 1 else {
            throw ValidationError("--from-folder, --mark-all, --leave-new 중 하나를 주세요.")
        }
    }

    func run() throws {
        try Terminal.run {
            // 훑기에 16초쯤 걸리므로 폴더 경로부터 확인합니다.
            if let folder {
                try FolderMatcher.requireReadable(folder.url)
            }
            let ledger = try ledgerOptions.open()
            let connection = try Connection.open(connection)
            defer { connection.close() }
            let scan = try connection.scanAlbum()
            let answer: FirstConnectAnswer = if let folder {
                .findInFolder(folder.url)
            } else if marksAll {
                .markAll
            } else {
                .leaveAllNew
            }
            let recorded = try ledger.answerFirstConnectQuestion(
                answer,
                captures: scan.captures,
                serialNumber: connection.info.serialNumber,
                isCancelled: { Terminal.isInterrupted }
            )
            print("기록에 넣은 캡처 \(recorded)개")
        }
    }
}
