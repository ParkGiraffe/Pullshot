import Foundation

public struct DateSections: Equatable, Sendable {
    public struct Day: Equatable, Sendable, Identifiable {
        public var start: Date
        public var captures: [Capture]

        public var id: Date {
            start
        }
    }

    public struct Month: Equatable, Sendable, Identifiable {
        public var start: Date
        public var days: [Day]

        public var id: Date {
            start
        }
    }

    public var months: [Month]
    public var undated: [Capture]

    public init(_ captures: [Capture], calendar: Calendar = .current) {
        let sorted = captures.sorted(by: Capture.newestFirst)
        undated = sorted.filter { $0.capturedAt == nil }
        let days = Dictionary(grouping: sorted.filter { $0.capturedAt != nil }) {
            calendar.startOfDay(for: $0.capturedAt ?? .distantPast)
        }
        .map { Day(start: $0, captures: $1) }
        .sorted { $0.start > $1.start }
        months = Dictionary(grouping: days) { calendar.dateInterval(of: .month, for: $0.start)?.start ?? $0.start }
            .map { Month(start: $0, days: $1) }
            .sorted { $0.start > $1.start }
    }
}
