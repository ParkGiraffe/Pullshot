import PullshotKit
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
                                Picker("필터", selection: Binding(get: { model.kind }, set: { model.filter($0) })) {
                                    Text("사진과 동영상").tag(KindFilter.all)
                                    Text("사진").tag(KindFilter.photos)
                                    Text("동영상").tag(KindFilter.videos)
                                }
                                .pickerStyle(.inline)
                            } label: {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                            }
                            // 이름이 없으면 접근성 이름이 펼침 화살표 이미지 이름(chevron.pulldown)이 됩니다(2026-11-17, macOS 27).
                            .accessibilityLabel("필터")
                        }
                    }
                    .onChange(of: captures.map(\.id)) { _, visible in model.keepVisible(visible) }
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
                selection: Binding(get: { model.selection }, set: { model.select($0) }),
                columns: $model.gridColumns
            ) { capture in
                model.serialNumber.map { !model.index.isTransferred(capture, serialNumber: $0) } ?? false
            } preview: {
                model.preview()
            } togglePreview: {
                model.togglePreview()
            }
            // 범위나 필터가 바뀌면 처음부터 보입니다. 스크롤 위치가 남으면 짧아진 격자 밖을 가리켜 빈 화면이 됩니다.
            // 보기 방식은 같은 캡처를 다르게 놓을 뿐이라 위치를 둡니다.
            .id(model.query)
        }
    }

    /// 제목은 보고 있는 종류를, 둘째 줄은 빈 까닭을 알립니다.
    private var emptyState: some View {
        let title: LocalizedStringKey = switch model.query.shownKind {
        case .all: "사진 또는 동영상이 없습니다"
        case .photos: "사진이 없습니다"
        case .videos: "동영상이 없습니다"
        }
        let reason: Text? = switch model.emptyReason {
        case .allTransferred: Text("새로 찍은 사진과 동영상을 모두 Mac으로 옮겼습니다.")
        case .noRecentTransfer: Text("최근 30일 동안 옮긴 사진과 동영상이 없습니다.")
        case .onlyPhotosShown: Text("필터에서 사진과 동영상을 고르면 동영상을 볼 수 있습니다.")
        case .onlyVideosShown: Text("필터에서 사진과 동영상을 고르면 사진을 볼 수 있습니다.")
        case nil: nil
        }
        return ContentUnavailableView(
            title,
            systemImage: model.scope == .new ? "tray" : "photo.on.rectangle",
            description: reason
        )
    }

    /// "11월 1일~14일 · 사진 80 · 동영상 6"처럼 보이는 캡처의 기간과 수입니다. 없는 칸은 뺍니다.
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
            parts.append(String(localized: "동영상 \(summary.videoCount)"))
        }
        return parts.joined(separator: " · ")
    }
}
