import PullshotKit
import QuickLook
import SwiftUI

struct LibraryWindow: View {
    @Bindable var model: LibraryModel
    @AppStorage(SettingsKey.thumbnailSize.rawValue) private var thumbnailSize = 180.0
    @AppStorage(SettingsKey.viewMode.rawValue) private var viewMode = ViewMode.newest
    /// 창이 좁으면 사용자가 둔 상태(`isInspectorShown`)와 상관없이 오른쪽 칸을 접습니다.
    @State private var isNarrow = false

    /// 기기를 열고 훑기를 마쳐 격자와 오른쪽 칸을 보일 수 있습니다.
    private var isReady: Bool {
        if case .ready = model.connection {
            true
        } else {
            false
        }
    }

    var body: some View {
        NavigationSplitView {
            Sidebar(model: model)
                .navigationSplitViewColumnWidth(236)
        } detail: {
            if isReady {
                let captures = model.visibleCaptures
                content(captures)
                    .navigationTitle(model.scope.title)
                    .navigationSubtitle(subtitle(of: captures))
                    .toolbar {
                        ToolbarItem {
                            // Liquid Glass 툴바는 항목을 안쪽 여백 없는 캡슐로 감싸, 여백을 두어야 아이콘이 캡슐 끝에 붙지 않습니다.
                            // 막대 폭은 창 폭 980pt에서도 격자 열 툴바 항목이 넘침 메뉴로 숨지 않는 폭입니다(2026-11-17, macOS 27, 제목이 짧을 때).
                            HStack(spacing: 0) {
                                Image(systemName: "minus")
                                Slider(value: $thumbnailSize, in: 120 ... 360)
                                    .controlSize(.mini)
                                    .frame(width: 80)
                                Image(systemName: "plus")
                            }
                            .padding(.horizontal, 10)
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
                            // 이름이 없으면 접근성 이름이 펼침 화살표 이미지 이름(chevron.pulldown)이 됩니다(2026-11-17, macOS 27).
                            .accessibilityLabel("종류")
                        }
                    }
                    .onChange(of: captures.map(\.id)) { _, visible in model.selection.keep(visible) }
                    .onChange(of: model.scope) { model.selection.clear() }
            } else {
                ConnectionGuide(model: model)
            }
        }
        // 오른쪽 칸을 창 전체에 붙이고 그 안에 툴바를 두어야 툴바가 열마다 나뉘어, 격자 툴바 항목이 오른쪽 칸 경계 앞에서 끝납니다.
        // 오른쪽 칸 툴바의 단추는 오른쪽 칸을 접어도 창 오른쪽 끝에 남으므로, 안내 화면에서는 오른쪽 칸 내용을 두지 않습니다.
        .inspector(isPresented: Binding(
            get: { isReady && model.isInspectorShown && !isNarrow },
            set: { isShown in
                if !isNarrow {
                    model.isInspectorShown = isShown
                }
            }
        )) {
            if isReady {
                Inspector(model: model, captures: model.visibleCaptures)
                    .toolbar {
                        Spacer()
                        Button("오른쪽 칸", systemImage: "sidebar.right") {
                            model.isInspectorShown.toggle()
                        }
                    }
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
                model.preview()
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
                description: Text("사이드바에서 다른 게임이나 목록을 고르거나 종류를 바꿔 주세요.")
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
