import PullshotKit
import SwiftUI

/// 오른쪽 칸입니다. 고른 것이 없으면 보는 범위의 정보와 새 항목, 모두 가져오기를, 고르면 고른 캡처의 정보와
/// 가져오기 설정을 둡니다. 저장 위치는 두 상태가 같은 설정을 씁니다.
struct Inspector: View {
    let model: LibraryModel
    /// 격자에 보이는 캡처입니다.
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
        let newCount = model.captures(in: .newItems).count
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
                model.startImport(.newItems)
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
            if let first = summary.first, let last = summary.last {
                row("찍은 때", Text(CaptureTimeText.current.span(first, last)))
            }
        }
        Divider()
        importFolderButton
        Toggle("폴더별로 나눠 저장", isOn: $settings.makesGameFolder)
        Picker("파일 이름", selection: $settings.exportNaming) {
            Text("원래 이름 그대로").tag(ExportNaming.original)
            Text("찍은 순서대로 번호 붙이기").tag(ExportNaming.numbered)
        }
        Text(verbatim: ExportPreview.lines(model.importItems(.selected)).joined(separator: "\n"))
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

    /// 저장 위치입니다. 누르면 폴더를 골라 바로 바꿉니다.
    private var importFolderButton: some View {
        Button {
            isChoosingImportFolder = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("저장 위치")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(verbatim: model.importFolder.abbreviatedPath)
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

    /// 최근 것을 맨 위에 두고 뒤의 두 장을 비스듬히 겹칩니다.
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
            label(title)
            value
        }
    }

    private func label(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .foregroundStyle(.secondary)
    }

    /// 크기를 아는 캡처만 더한 값을 1000 단위로 씁니다.
    private func size(_ summary: CaptureSummary) -> Text {
        Text(verbatim: ByteCountFormatter.string(fromByteCount: Int64(summary.totalSize), countStyle: .decimal))
    }
}

extension URL {
    /// 홈 폴더를 `~`로 줄인 경로입니다. 폴더 고르기가 돌려준 URL의 끝 `/`는 뗍니다.
    var abbreviatedPath: String {
        ((path(percentEncoded: false) as NSString).standardizingPath as NSString).abbreviatingWithTildeInPath
    }
}
