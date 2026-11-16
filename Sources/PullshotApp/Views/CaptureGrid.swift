import PullshotKit
import SwiftUI

enum ViewMode: String, CaseIterable {
    case newest
    case byDate
}

struct CaptureGrid: View {
    let captures: [Capture]
    let viewMode: ViewMode
    let cellWidth: CGFloat
    let isNew: (Capture) -> Bool

    var body: some View {
        switch viewMode {
        case .newest:
            grid(captures.sorted(by: Capture.newestFirst))
                .padding(12)
        case .byDate:
            byDate
        }
    }

    private var byDate: some View {
        let sections = DateSections(captures)
        return LazyVStack(alignment: .leading, spacing: 16) {
            ForEach(sections.months) { month in
                VStack(alignment: .leading, spacing: 10) {
                    monthHeader(month)
                    ForEach(month.days) { day in
                        VStack(alignment: .leading, spacing: 6) {
                            dayHeader(day)
                            grid(day.captures)
                        }
                    }
                }
            }
            if !sections.undated.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("날짜 모름").font(.headline)
                    grid(sections.undated)
                }
            }
        }
        .padding(12)
    }

    private func grid(_ captures: [Capture]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: cellWidth), spacing: 3)], spacing: 3) {
            ForEach(captures) { capture in
                CaptureCell(capture: capture, isNew: isNew(capture))
            }
        }
    }

    private func monthHeader(_ month: DateSections.Month) -> some View {
        let summary = CaptureSummary(month.days.flatMap(\.captures))
        return VStack(alignment: .leading, spacing: 2) {
            Text(month.start, format: .dateTime.month(.wide))
                .font(.title.bold())
            Text("\(month.start.formatted(.dateTime.year())) · \(countText(summary))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func dayHeader(_ day: DateSections.Day) -> some View {
        let summary = CaptureSummary(day.captures)
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(day.start, format: .dateTime.day().weekday(.wide))
                .font(.headline)
            Text(timeRange(summary))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    /// 0개인 종류는 뺍니다.
    private func countText(_ summary: CaptureSummary) -> String {
        [
            summary.photoCount > 0 ? String(localized: "사진 \(summary.photoCount)") : nil,
            summary.videoCount > 0 ? String(localized: "영상 \(summary.videoCount)") : nil,
        ]
        .compactMap(\.self)
        .joined(separator: " · ")
    }

    /// 시각은 로케일에 맞춰 만듭니다. 두 시각의 때(한국어는 "밤")가 같으면 둘째는 때 없이 "밤 10:02 ~ 11:48"로 씁니다.
    private func timeRange(_ summary: CaptureSummary) -> String {
        guard let first = summary.first, let last = summary.last else { return "" }
        guard Self.dayPeriodFormatter.string(from: first) == Self.dayPeriodFormatter.string(from: last) else {
            return "\(Self.timeFormatter.string(from: first)) ~ \(Self.timeFormatter.string(from: last))"
        }
        return first == last
            ? Self.timeFormatter.string(from: first)
            : "\(Self.timeFormatter.string(from: first)) ~ \(Self.timeWithoutPeriodFormatter.string(from: last))"
    }

    private static let timePattern = DateFormatter.dateFormat(fromTemplate: "Bhmm", options: 0, locale: .current)
        ?? "h:mm"
    private static let timeFormatter = formatter(timePattern)
    private static let timeWithoutPeriodFormatter = formatter(
        timePattern.replacing("B", with: "").trimmingCharacters(in: .whitespaces)
    )
    private static let dayPeriodFormatter = formatter("B")

    private static func formatter(_ pattern: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = pattern
        return formatter
    }
}
