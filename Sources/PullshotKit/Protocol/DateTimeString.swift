import Foundation

/// PTP 날짜 문자열 `YYYYMMDDThhmmss[.s][Z|±hhmm]`을 읽습니다.
public enum DateTimeString {
    /// 시간대가 없으면 `timeZone`으로 읽고, 2월 30일처럼 없는 날짜면 nil입니다.
    public static func parse(_ text: String, timeZone: TimeZone) -> Date? {
        let pattern = /(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(?:\.\d+)?(Z|[+-]\d{4})?/
        guard let match = text.wholeMatch(of: pattern) else { return nil }
        let (_, year, month, day, hour, minute, second, zone) = match.output
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone.flatMap(offset) ?? timeZone
        let components = DateComponents(
            year: Int(year), month: Int(month), day: Int(day),
            hour: Int(hour), minute: Int(minute), second: Int(second)
        )
        guard let date = calendar.date(from: components) else { return nil }
        // Calendar는 없는 날짜를 다음 달로 넘기므로, 되풀어 입력과 같은지 확인합니다.
        let roundTrip = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return roundTrip == components ? date : nil
    }

    private static func offset(_ zone: Substring) -> TimeZone? {
        guard zone != "Z" else { return .gmt }
        guard let hours = Int(zone.dropFirst().prefix(2)), let minutes = Int(zone.suffix(2)) else { return nil }
        let seconds = (hours * 3600 + minutes * 60) * (zone.first == "-" ? -1 : 1)
        return TimeZone(secondsFromGMT: seconds)
    }
}
