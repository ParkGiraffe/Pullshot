import PullshotKit
import SwiftUI

struct LibraryWindow: View {
    let model: LibraryModel
    @AppStorage(SettingsKey.thumbnailSize.rawValue) private var thumbnailSize = 180.0
    @AppStorage(SettingsKey.viewMode.rawValue) private var viewMode = ViewMode.newest

    var body: some View {
        NavigationSplitView {
            DeviceSwitcher(model: model)
                .padding(.horizontal, 10)
                .frame(maxHeight: .infinity, alignment: .top)
                .navigationSplitViewColumnWidth(236)
        } detail: {
            if case .ready = model.connection {
                ScrollView {
                    CaptureGrid(captures: model.captures, viewMode: viewMode, cellWidth: thumbnailSize) { capture in
                        model.serialNumber.map { !model.index.isTransferred(capture, serialNumber: $0) } ?? false
                    }
                }
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
                }
            } else {
                ConnectionGuide(model: model)
            }
        }
        .environment(model.thumbnails)
        .task { await model.watchConsoles() }
    }
}
