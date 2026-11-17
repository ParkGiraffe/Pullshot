import AppKit
import PullshotKit
import SwiftUI

enum ViewMode: String {
    case newest
    case byDate
}

/// 캡처 격자입니다. 누르기와 키보드로 캡처를 고르고, 스페이스나 두 번 누르기로 기준 캡처를 크게 봅니다.
struct CaptureGrid: View {
    let captures: [Capture]
    let viewMode: ViewMode
    let cellWidth: CGFloat
    @Binding var selection: GridSelection
    let isNew: (Capture) -> Bool
    let preview: () -> Void
    @FocusState private var isFocused: Bool
    /// 격자가 실제로 놓이는 폭입니다. 스크롤 막대가 늘 보이는 설정에서는 그 폭만큼 좁아집니다.
    @State private var gridWidth: CGFloat = 0

    private static let margin: CGFloat = 12
    private static let gap: CGFloat = 3

    var body: some View {
        // 날짜 보기도 달, 날, 날 안의 캡처가 모두 최신순이라 두 보기의 칸 순서가 같습니다. 고르기와 화살표는 이 순서를 씁니다.
        let ordered = captures.sorted(by: Capture.newestFirst)
        let order = ordered.map(\.id)
        GeometryReader { viewport in
            ScrollViewReader { scroller in
                ScrollView {
                    Group {
                        switch viewMode {
                        case .newest: grid(ordered, order: order)
                        case .byDate: byDate(ordered, order: order)
                        }
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { gridWidth = $0 }
                    .padding(Self.margin)
                    // 캡처가 적어도 아래 빈 곳을 눌러 고른 것을 지울 수 있게 보이는 높이까지 채웁니다.
                    .frame(minHeight: viewport.size.height, alignment: .top)
                    .contentShape(.rect)
                    .onTapGesture {
                        selection.clear()
                        isFocused = true
                    }
                }
                .focusable()
                .focusEffectDisabled()
                .focused($isFocused)
                .onKeyPress(.leftArrow) { move(.left, in: order, scroller: scroller) }
                .onKeyPress(.rightArrow) { move(.right, in: order, scroller: scroller) }
                .onKeyPress(.upArrow) { move(.up, in: order, scroller: scroller) }
                .onKeyPress(.downArrow) { move(.down, in: order, scroller: scroller) }
                .onKeyPress(.space) {
                    preview()
                    return .handled
                }
                .onKeyPress(.escape) {
                    selection.clear()
                    return .handled
                }
                // 찾기 칸에 초점이 있을 때는 ⌘A가 글자를 고르도록 넘깁니다.
                .onCommand(
                    #selector(NSResponder.selectAll(_:)),
                    perform: isFocused ? { selection.selectAll(order) } : nil
                )
            }
        }
    }

    private func byDate(_ captures: [Capture], order: [Capture.ID]) -> some View {
        let sections = DateSections(captures)
        return LazyVStack(alignment: .leading, spacing: 16) {
            ForEach(sections.months) { month in
                VStack(alignment: .leading, spacing: 10) {
                    monthHeader(month)
                    ForEach(month.days) { day in
                        VStack(alignment: .leading, spacing: 6) {
                            dayHeader(day)
                            grid(day.captures, order: order)
                        }
                    }
                }
            }
            if !sections.undated.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("날짜 모름").font(.headline)
                    grid(sections.undated, order: order)
                }
            }
        }
    }

    private func grid(_ captures: [Capture], order: [Capture.ID]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: cellWidth), spacing: Self.gap)], spacing: Self.gap) {
            ForEach(captures) { capture in
                CaptureCell(
                    capture: capture,
                    isNew: isNew(capture),
                    isSelected: selection.selected.contains(capture.id)
                )
                .onTapGesture { click(capture.id, in: order) }
            }
        }
    }

    /// ⌘를 누른 채면 넣고 빼기, ⇧를 누른 채면 기준부터 이어 고르기입니다. 두 번 누르면 그 캡처를 크게 봅니다.
    private func click(_ id: Capture.ID, in order: [Capture.ID]) {
        let modifiers = NSEvent.modifierFlags
        let click: GridSelection.Click = if modifiers.contains(.command) {
            .toggle
        } else if modifiers.contains(.shift) {
            .extend
        } else {
            .only
        }
        selection.click(id, click, in: order)
        isFocused = true
        if NSApp.currentEvent?.clickCount == 2 {
            preview()
        }
    }

    /// 한 줄은 격자가 놓이는 폭과 간격으로 센 열 수입니다. 고른 칸이 화면 밖으로 나가면 따라 스크롤합니다.
    private func move(
        _ move: GridSelection.Move,
        in order: [Capture.ID],
        scroller: ScrollViewProxy
    ) -> KeyPress.Result {
        let columns = GridSelection.columns(width: gridWidth, minimum: cellWidth, spacing: Self.gap)
        selection.move(move, columns: columns, in: order)
        if let anchor = selection.anchor {
            scroller.scrollTo(anchor)
        }
        return .handled
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
            summary.videoCount > 0 ? String(localized: "동영상 \(summary.videoCount)") : nil,
        ]
        .compactMap(\.self)
        .joined(separator: " · ")
    }

    private func timeRange(_ summary: CaptureSummary) -> String {
        guard let first = summary.first, let last = summary.last else { return "" }
        return CaptureTimeText.current.timeRange(first, last)
    }
}
