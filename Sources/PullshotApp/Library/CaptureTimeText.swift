import Foundation

struct CaptureTimeText {
    static let current = Self(locale: .current, timeZone: .current)

    private let time: DateFormatter
    private let timeWithoutPeriod: DateFormatter
    private let dayPeriod: DateFormatter

    init(locale: Locale, timeZone: TimeZone) {
        func formatter(_ pattern: String) -> DateFormatter {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.timeZone = timeZone
            formatter.dateFormat = pattern
            return formatter
        }
        let timePattern = DateFormatter.dateFormat(fromTemplate: "Bhmm", options: 0, locale: locale) ?? "h:mm"
        time = formatter(timePattern)
        timeWithoutPeriod = formatter(timePattern.replacing("B", with: "").trimmingCharacters(in: .whitespaces))
        dayPeriod = formatter("B")
    }

    func timeRange(_ first: Date, _ last: Date) -> String {
        guard dayPeriod.string(from: first) == dayPeriod.string(from: last) else {
            return "\(time.string(from: first)) ~ \(time.string(from: last))"
        }
        return first == last
            ? time.string(from: first)
            : "\(time.string(from: first)) ~ \(timeWithoutPeriod.string(from: last))"
    }
}
