import Foundation

public enum FirstConnectAnswer: Equatable, Sendable {
    case findInFolder(URL)
    case markAll
    case leaveAllNew
}

public extension TransferLedger {
    func needsFirstConnectQuestion(serialNumber: String) -> Bool {
        !answeredSerialNumbers.contains(serialNumber) && !index.hasRecords(for: serialNumber)
    }

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
