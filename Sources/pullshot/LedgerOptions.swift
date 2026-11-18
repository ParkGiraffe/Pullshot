import ArgumentParser
import Foundation
import PullshotKit

struct LedgerOptions: ParsableArguments {
    @Option(
        name: .customLong("ledger-folder"),
        help: "옮긴 기록을 저장할 폴더입니다. 기본값은 ~/Library/Application Support/Pullshot입니다."
    )
    var folder: Path?

    func open() throws -> TransferLedger {
        try TransferLedger(directory: folder?.url ?? TransferLedger.defaultDirectory)
    }
}

extension TransferLedger {
    func hintIfFirstConnection(serialNumber: String) {
        guard shouldAskFirstConnectQuestion(serialNumber: serialNumber) else { return }
        Terminal.error("처음 연결한 기기입니다. Mac에 이미 저장한 사진과 동영상이 있으면 pullshot ledger --from-folder <폴더>로 옮긴 기록에 추가해 주세요.")
    }
}
