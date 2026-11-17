import PullshotKit
import SwiftUI

struct LibraryWindow: View {
    @Bindable var model: LibraryModel
    @AppStorage(SettingsKey.thumbnailSize.rawValue) private var thumbnailSize = 180.0
    @AppStorage(SettingsKey.viewMode.rawValue) private var viewMode = ViewMode.newest

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
                    .overlay {
                        if model.isFirstConnectQuestionShown {
                            FirstConnectQuestion(model: model)
                        }
                    }
                    .navigationTitle(model.scope.title)
                    .navigationSubtitle(subtitle(of: captures))
                    .toolbar {
                        ToolbarItem {
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
                                Picker("필터", selection: Binding(get: { model.kindFilter }, set: { model.filter($0) })) {
                                    Text("사진과 동영상").tag(KindFilter.all)
                                    Text("사진").tag(KindFilter.photos)
                                    Text("동영상").tag(KindFilter.videos)
                                }
                                .pickerStyle(.inline)
                            } label: {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                            }
                            .accessibilityLabel("필터")
                        }
                    }
                    .onChange(of: captures.map(\.id)) { _, visible in model.keepVisible(visible) }
            } else {
                ConnectionGuide(model: model)
            }
        }
        .inspector(isPresented: Binding(
            get: { isReady && model.isInspectorShown },
            set: { model.isInspectorShown = $0 }
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
                gridRows: $model.gridRows
            ) { capture in
                model.serialNumber.map { !model.ledgerIndex.isTransferred(capture, serialNumber: $0) } ?? false
            } preview: {
                model.preview()
            } togglePreview: {
                model.togglePreview()
            }
            .id(model.query)
        }
    }

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

    private func subtitle(of captures: [Capture]) -> String {
        let summary = CaptureSummary(captures)
        var parts: [String] = []
        if let first = summary.firstCapturedAt, let last = summary.lastCapturedAt {
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
