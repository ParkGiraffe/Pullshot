import ArgumentParser
import Foundation
import PullshotKit

struct LedgerOptions: ParsableArguments {
    @Option(
        name: .customLong("ledger-folder"),
        help: "옮긴 기록을 둘 폴더입니다. 기본은 ~/Library/Application Support/Pullshot입니다."
    )
    var folder: String?

    func open() throws -> TransferLedger {
        let directory = folder.map { URL(filePath: ($0 as NSString).expandingTildeInPath) }
        return try TransferLedger(directory: directory ?? TransferLedger.defaultDirectory)
    }
}

extension TransferLedger {
    /// 처음 연결한 기기면 이미 받아 둔 캡처를 기록에 넣는 방법을 알립니다. 목록과 받기는 그대로 이어 갑니다.
    func hintIfFirstConnection(serialNumber: String) {
        guard needsFirstConnectQuestion(serialNumber: serialNumber) else { return }
        Terminal.error("처음 연결한 기기입니다. 이미 받아 둔 캡처가 있으면 pullshot ledger --from-folder <폴더>로 기록에 넣어 주세요.")
    }
}
