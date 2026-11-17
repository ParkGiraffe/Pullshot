import AppKit
import PullshotKit
import SwiftUI

enum ViewMode: String {
    case newest
    case byDate
}

struct CaptureGrid: View {
    let captures: [Capture]
    let viewMode: ViewMode
    let cellWidth: CGFloat
    @Binding var selection: GridSelection
    @Binding var columns: Int
    let isNew: (Capture) -> Bool
    let preview: () -> Void
    let togglePreview: () -> Void
    @FocusState private var isFocused: Bool
    @State private var gridWidth: CGFloat = 0

    private static let margin: CGFloat = 12
    private static let gap: CGFloat = 3

    private var columnCount: Int {
        GridSelection.columns(width: gridWidth, minimum: cellWidth, spacing: Self.gap)
    }

    var body: some View {
        let order = captures.map(\.id)
        GeometryReader { viewport in
            ScrollViewReader { scroller in
                ScrollView {
                    Group {
                        switch viewMode {
                        case .newest: grid(captures, order: order)
                        case .byDate: byDate(captures, order: order)
                        }
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { gridWidth = $0 }
                    .padding(Self.margin)
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
                .onKeyPress(.leftArrow) { move(.left, in: order) }
                .onKeyPress(.rightArrow) { move(.right, in: order) }
                .onKeyPress(.upArrow) { move(.up, in: order) }
                .onKeyPress(.downArrow) { move(.down, in: order) }
                .onKeyPress(.space) {
                    togglePreview()
                    return .handled
                }
                .onKeyPress(.escape) {
                    selection.clear()
                    return .handled
                }
                .onCommand(
                    #selector(NSResponder.selectAll(_:)),
                    perform: isFocused ? { selection.selectAll(order) } : nil
                )
                .onChange(of: selection.anchor) { _, anchor in
                    if let anchor {
                        scroller.scrollTo(anchor)
                    }
                }
                .onChange(of: columnCount, initial: true) { columns = columnCount }
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

    private func move(_ move: GridSelection.Move, in order: [Capture.ID]) -> KeyPress.Result {
        selection.move(move, columns: columnCount, in: order)
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
