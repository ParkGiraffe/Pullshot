import Foundation

struct CaptureTimeText {
    static let current = Self(locale: .current, timeZone: .current)

    private let calendar: Calendar
    private let time: DateFormatter
    private let timeWithoutPeriod: DateFormatter
    private let dayPeriod: DateFormatter
    private let day: Date.FormatStyle
    private let days: Date.IntervalFormatStyle

    init(locale: Locale, timeZone: TimeZone) {
        func formatter(_ pattern: String) -> DateFormatter {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.timeZone = timeZone
            formatter.dateFormat = pattern
            return formatter
        }
        var calendar = Calendar.current
        calendar.locale = locale
        calendar.timeZone = timeZone
        self.calendar = calendar
        let timePattern = DateFormatter.dateFormat(fromTemplate: "Bhmm", options: 0, locale: locale) ?? "h:mm"
        time = formatter(timePattern)
        timeWithoutPeriod = formatter(timePattern.replacing("B", with: "").trimmingCharacters(in: .whitespaces))
        dayPeriod = formatter("B")
        day = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: timeZone).month().day()
        days = Date.IntervalFormatStyle(locale: locale, calendar: calendar, timeZone: timeZone).month().day()
    }

    func timeRange(_ first: Date, _ last: Date) -> String {
        guard dayPeriod.string(from: first) == dayPeriod.string(from: last) else {
            return "\(time.string(from: first)) ~ \(time.string(from: last))"
        }
        return first == last
            ? time.string(from: first)
            : "\(time.string(from: first)) ~ \(timeWithoutPeriod.string(from: last))"
    }

    func span(_ first: Date, _ last: Date) -> String {
        guard calendar.isDate(first, inSameDayAs: last) else { return (first ..< last).formatted(days) }
        return "\(first.formatted(day)) \(timeRange(first, last))"
    }
}
