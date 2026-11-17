import Foundation

public struct LastTransfer: Equatable, Sendable {
    public var day: Date
    public var count: Int
}

public struct LedgerIndex: Equatable, Sendable {
    private var recorded: Set<CaptureKey> = []
    private var lastTransferDates: [CaptureKey: Date] = [:]

    public init() {}

    public func isTransferred(_ capture: Capture, serialNumber: String) -> Bool {
        recorded.contains(CaptureKey(capture, serialNumber: serialNumber))
    }

    public func newCaptures(_ captures: [Capture], serialNumber: String) -> [Capture] {
        captures.filter { !isTransferred($0, serialNumber: serialNumber) }
    }

    public func transferredAt(_ capture: Capture, serialNumber: String) -> Date? {
        lastTransferDates[CaptureKey(capture, serialNumber: serialNumber)]
    }

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
