import Foundation

/// 찍은 때를 글로 씁니다. 날짜 보기의 날 머리와 오른쪽 칸이 같은 꼴을 쓰도록 한곳에 둡니다.
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

    /// 시각은 로케일에 맞춰 만듭니다. 두 시각의 때(한국어는 "밤")가 같으면 둘째는 때 없이 "밤 10:02 ~ 11:48"로 씁니다.
    func timeRange(_ first: Date, _ last: Date) -> String {
        guard dayPeriod.string(from: first) == dayPeriod.string(from: last) else {
            return "\(time.string(from: first)) ~ \(time.string(from: last))"
        }
        return first == last
            ? time.string(from: first)
            : "\(time.string(from: first)) ~ \(timeWithoutPeriod.string(from: last))"
    }

    /// 같은 날이면 "11월 6일 밤 10:02 ~ 11:41"처럼 시각까지, 여러 날에 걸치면 "10월 29일~11월 16일"처럼 날짜만 씁니다.
    func span(_ first: Date, _ last: Date) -> String {
        guard calendar.isDate(first, inSameDayAs: last) else { return (first ..< last).formatted(days) }
        return "\(first.formatted(day)) \(timeRange(first, last))"
    }
}
