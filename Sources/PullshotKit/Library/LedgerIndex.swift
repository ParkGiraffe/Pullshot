import Foundation

/// 지난번 옮긴 날(그날 0시)과 그날 옮긴 캡처 수입니다.
public struct LastTransfer: Equatable, Sendable {
    public var day: Date
    public var count: Int
}

/// 옮긴 기록의 색인입니다. 파일을 쥔 `TransferLedger`와 달리 값이라 화면이 들고 있을 수 있습니다.
public struct LedgerIndex: Equatable, Sendable {
    private var recorded: Set<CaptureKey> = []
    /// 가져오기나 내보내기로 마지막으로 옮긴 때입니다.
    private var lastTransferDates: [CaptureKey: Date] = [:]

    public init() {}

    public func isTransferred(_ capture: Capture, serialNumber: String) -> Bool {
        recorded.contains(CaptureKey(capture, serialNumber: serialNumber))
    }

    public func newCaptures(_ captures: [Capture], serialNumber: String) -> [Capture] {
        captures.filter { !isTransferred($0, serialNumber: serialNumber) }
    }

    /// 가져오기나 내보내기로 마지막으로 옮긴 때입니다. 처음 연결 답으로만 기록된 캡처는 nil입니다.
    public func transferredAt(_ capture: Capture, serialNumber: String) -> Date? {
        lastTransferDates[CaptureKey(capture, serialNumber: serialNumber)]
    }

    /// 주어진 캡처 가운데 가장 늦게 옮긴 날과, 그날 옮긴 캡처 수입니다.
    public func lastTransfer(
        of captures: [Capture],
        serialNumber: String,
        calendar: Calendar = .current
    ) -> LastTransfer? {
        let dates = captures.compactMap { transferredAt($0, serialNumber: serialNumber) }
        guard let latest = dates.max() else { return nil }
        let day = calendar.startOfDay(for: latest)
        return LastTransfer(day: day, count: dates.count { calendar.isDate($0, inSameDayAs: day) })
    }

    /// 기준 시각과 같거나 뒤에 가져오거나 내보낸 캡처를 입력 순서대로 돌려줍니다.
    public func recentlyTransferred(_ captures: [Capture], serialNumber: String, since: Date) -> [Capture] {
        captures.filter { transferredAt($0, serialNumber: serialNumber).map { $0 >= since } ?? false }
    }

    func hasRecords(for serialNumber: String) -> Bool {
        recorded.contains { $0.serialNumber == serialNumber }
    }

    mutating func insert(_ entry: LedgerEntry) {
        recorded.insert(entry.key)
        guard entry.kind.isActualTransfer else { return }
        lastTransferDates[entry.key] = max(entry.date, lastTransferDates[entry.key] ?? entry.date)
    }
}
