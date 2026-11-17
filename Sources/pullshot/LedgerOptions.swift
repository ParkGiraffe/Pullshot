import ArgumentParser
import Foundation
import PullshotKit

struct LedgerOptions: ParsableArguments {
    @Option(
        name: .customLong("ledger-folder"),
        help: "옮긴 기록을 둘 폴더입니다. 기본은 ~/Library/Application Support/Pullshot입니다."
    )
    var folder: Path?

    func open() throws -> TransferLedger {
        try TransferLedger(directory: folder?.url ?? TransferLedger.defaultDirectory)
    }
}

extension TransferLedger {
    func hintIfFirstConnection(serialNumber: String) {
        guard shouldAskFirstConnectQuestion(serialNumber: serialNumber) else { return }
        Terminal.error("처음 연결한 기기입니다. 이미 받아 둔 캡처가 있으면 pullshot ledger --from-folder <폴더>로 옮긴 기록에 넣어 주세요.")
    }
}
