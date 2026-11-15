import Foundation

/// 처음 연결 질문의 답입니다(설계 6.3).
public enum FirstConnectAnswer: Equatable, Sendable {
    /// 고른 폴더 아래 어디에 있든 파일 이름과 크기가 같은 캡처를 옮긴 것으로 기록합니다.
    case findInFolder(URL)
    /// 지금 있는 캡처를 모두 옮긴 것으로 기록합니다.
    case markAll
    /// 기록하지 않아 모두 새 항목으로 둡니다.
    case leaveAllNew
}

/// 기록이 빈 기기를 처음 연결하면 모든 캡처가 새 항목이 됩니다. 그래서 지금까지 받아 둔 캡처를 기록에 넣을지 한 번만 묻습니다.
public extension TransferLedger {
    func needsFirstConnectQuestion(serialNumber: String) -> Bool {
        !answeredSerialNumbers.contains(serialNumber) && !hasRecords(for: serialNumber)
    }

    /// 기록에 넣은 캡처 수를 돌려줍니다. 취소하면 아무것도 남기지 않아 다음 연결에서 다시 묻습니다.
    func answerFirstConnectQuestion(
        _ answer: FirstConnectAnswer,
        captures: [Capture],
        serialNumber: String,
        isCancelled: () -> Bool = { false }
    ) throws -> Int {
        let (found, kind): ([Capture], TransferKind) = switch answer {
        case let .findInFolder(folder):
            try (FolderMatcher.captures(captures, foundUnder: folder, isCancelled: isCancelled), .foundInFolder)
        case .markAll:
            (captures, .markedAll)
        case .leaveAllNew:
            ([], .markedAll)
        }
        try record(found, serialNumber: serialNumber, as: kind)
        try markAnswered(serialNumber)
        return found.count
    }
}
