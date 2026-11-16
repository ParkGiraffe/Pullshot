import PullshotKit
import QuickLook
import SwiftUI

struct LibraryWindow: View {
    @Bindable var model: LibraryModel
    @AppStorage(SettingsKey.thumbnailSize.rawValue) private var thumbnailSize = 180.0
    @AppStorage(SettingsKey.viewMode.rawValue) private var viewMode = ViewMode.newest
    /// 창이 좁으면 사용자가 둔 상태(`isInspectorShown`)와 상관없이 오른쪽 칸을 접습니다.
    @State private var isNarrow = false

    var body: some View {
        NavigationSplitView {
            Sidebar(model: model)
                .navigationSplitViewColumnWidth(236)
        } detail: {
            if case .ready = model.connection {
                let captures = model.visibleCaptures
                content(captures)
                    .navigationTitle(model.scope.title)
                    .navigationSubtitle(subtitle(of: captures))
                    .toolbar {
                        ToolbarItem {
                            HStack {
                                Image(systemName: "minus.magnifyingglass")
                                Slider(value: $thumbnailSize, in: 120 ... 360)
                                    .frame(width: 100)
                                Image(systemName: "plus.magnifyingglass")
                            }
                            .foregroundStyle(.secondary)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("썸네일 크기")
                        }
                        ToolbarItem {
                            Picker("보기 방식", selection: $viewMode) {
                                Text("최신순").tag(ViewMode.newest)
                                Text("날짜").tag(ViewMode.byDate)
                            }
                            .pickerStyle(.segmented)
                        }
                        ToolbarItem {
                            Menu {
                                Picker("종류", selection: $model.kind) {
                                    Text("사진과 영상").tag(KindFilter.all)
                                    Text("사진").tag(KindFilter.photos)
                                    Text("영상").tag(KindFilter.videos)
                                }
                                .pickerStyle(.inline)
                            } label: {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                            }
                        }
                        ToolbarItem {
                            Button("오른쪽 칸", systemImage: "sidebar.right") {
                                model.isInspectorShown.toggle()
                            }
                        }
                    }
                    .inspector(isPresented: Binding(
                        get: { model.isInspectorShown && !isNarrow },
                        set: { isShown in
                            if !isNarrow {
                                model.isInspectorShown = isShown
                            }
                        }
                    )) {
                        Inspector(model: model, captures: captures)
                    }
                    .onChange(of: captures.map(\.id)) { _, visible in model.selection.keep(visible) }
                    .onChange(of: model.scope) { model.selection.clear() }
            } else {
                ConnectionGuide(model: model)
            }
        }
        .onGeometryChange(for: Bool.self) { $0.size.width < 980 } action: { isNarrow = $0 }
        .quickLookPreview($model.previewURL)
        .sheet(isPresented: $model.isAskingFirstConnect) {
            FirstConnectSheet(model: model)
        }
        .environment(model.thumbnails)
        .task { await model.watchConsoles() }
    }

    @ViewBuilder private func content(_ captures: [Capture]) -> some View {
        if captures.isEmpty {
            emptyState
        } else {
            CaptureGrid(
                captures: captures,
                viewMode: viewMode,
                cellWidth: thumbnailSize,
                selection: $model.selection
            ) { capture in
                model.serialNumber.map { !model.index.isTransferred(capture, serialNumber: $0) } ?? false
            } preview: {
                Task { await model.preview() }
            }
            .id(model.scope)
        }
    }

    @ViewBuilder private var emptyState: some View {
        if model.scope == .new {
            ContentUnavailableView("새 항목이 없습니다", systemImage: "tray", description: Text("모든 캡처를 Mac으로 옮겼습니다."))
        } else {
            ContentUnavailableView(
                "캡처가 없습니다",
                systemImage: "photo.on.rectangle",
                description: Text("다른 범위나 종류를 골라 보세요.")
            )
        }
    }

    /// "11월 1일~14일 · 사진 80 · 영상 6"처럼 보이는 캡처의 기간과 수입니다. 없는 칸은 뺍니다.
    private func subtitle(of captures: [Capture]) -> String {
        let summary = CaptureSummary(captures)
        var parts: [String] = []
        if let first = summary.first, let last = summary.last {
            parts.append((first ..< last).formatted(.interval.month().day()))
        }
        if summary.photoCount > 0 {
            parts.append(String(localized: "사진 \(summary.photoCount)"))
        }
        if summary.videoCount > 0 {
            parts.append(String(localized: "영상 \(summary.videoCount)"))
        }
        return parts.joined(separator: " · ")
    }
}
