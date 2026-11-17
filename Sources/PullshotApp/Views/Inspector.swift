import PullshotKit
import SwiftUI

struct Inspector: View {
    let model: LibraryModel
    let captures: [Capture]
    @State private var isChoosingImportFolder = false

    var body: some View {
        let selected = model.selectedCaptures
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if selected.isEmpty {
                    scopeInfo
                } else {
                    selectionInfo(selected)
                }
            }
            .padding(14)
        }
        .inspectorColumnWidth(280)
    }

    @ViewBuilder private var scopeInfo: some View {
        let summary = CaptureSummary(captures)
        let newCount = model.captures(in: .new).count
        if let latest = captures.min(by: Capture.newestFirst) {
            Thumbnail(capture: latest)
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 8))
        }
        field(model.scope.title)
        properties("정보") {
            row("항목", Text("\(captures.count)개"))
            row("사진", Text("\(summary.photoCount)개"))
            row("동영상", Text("\(summary.videoCount)개"))
            row("크기", size(summary))
            row("새 항목", Text("\(newCount)개"))
        }
        Divider()
        importFolderButton
        if let run = model.transferRun {
            TransferPanel(run: run, model: model)
        } else {
            Button {
                model.startImport(.new)
            } label: {
                Label("새 항목 \(newCount)개 가져오기", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(newCount == 0 || model.isDemo)
            Button {
                model.startImport(.all)
            } label: {
                Text("모두 가져오기")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .disabled(captures.isEmpty || model.isDemo)
        }
    }

    @ViewBuilder private func selectionInfo(_ selected: [Capture]) -> some View {
        @Bindable var settings = model.settings
        let summary = CaptureSummary(selected)
        stack(Array(selected.prefix(3)))
        field(Text("\(selected.count)개 고름"))
        properties("고른 항목") {
            row("사진", Text("\(summary.photoCount)개"))
            row("동영상", Text("\(summary.videoCount)개"))
            row("크기", size(summary))
        }
        Divider()
        importFolderButton
        Toggle("폴더별로 나눠 저장", isOn: $settings.shouldMakeGameFolder)
        Picker("파일 이름", selection: $settings.importNaming) {
            Text("원래 이름 그대로").tag(ExportNaming.original)
            Text("찍은 순서대로 번호 붙이기").tag(ExportNaming.numbered)
        }
        Text(verbatim: ImportPreview.lines(model.importItems(.selected)).joined(separator: "\n"))
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.quaternary, in: .rect(cornerRadius: 8))
        if let run = model.transferRun {
            TransferPanel(run: run, model: model)
        } else {
            Button {
                model.startImport(.selected)
            } label: {
                Label("\(selected.count)개 가져오기", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.isDemo)
        }
    }

    private var importFolderButton: some View {
        Button {
            isChoosingImportFolder = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("저장 위치")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(verbatim: model.settings.importFolder.abbreviatedPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 0)
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.quaternary, in: .rect(cornerRadius: 8))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .fileImporter(isPresented: $isChoosingImportFolder, allowedContentTypes: [.folder]) { result in
            if case let .success(folder) = result {
                model.settings.importFolder = folder
            }
        }
    }

    private func stack(_ captures: [Capture]) -> some View {
        ZStack {
            ForEach(Array(captures.enumerated()), id: \.element.id) { offset, capture in
                Thumbnail(capture: capture)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .frame(width: 190)
                    .clipShape(.rect(cornerRadius: 7))
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                    .rotationEffect(.degrees(Self.tilts[offset]))
                    .offset(x: Self.shifts[offset])
                    .zIndex(-Double(offset))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 128)
    }

    private static let tilts: [Double] = [0, 4, -5]
    private static let shifts: [CGFloat] = [0, 14, -14]

    private func field(_ text: Text) -> some View {
        text
            .font(.headline)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(.quaternary, in: .rect(cornerRadius: 8))
    }

    private func properties(_ title: LocalizedStringKey, @ViewBuilder rows: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 7) {
                rows()
            }
            .monospacedDigit()
        }
    }

    private func row(_ title: LocalizedStringKey, _ value: Text) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            value
        }
    }

    private func size(_ summary: CaptureSummary) -> Text {
        Text(verbatim: ByteCountFormatter.string(fromByteCount: Int64(summary.totalSize), countStyle: .decimal))
    }
}

extension URL {
    var abbreviatedPath: String {
        ((path(percentEncoded: false) as NSString).standardizingPath as NSString).abbreviatingWithTildeInPath
    }
}
