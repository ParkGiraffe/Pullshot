import PullshotKit
import SwiftUI

/// 오른쪽 칸입니다. 고른 것이 없으면 보는 범위의 정보와 가져오기, 고르면 고른 캡처의 정보와 내보내기 설정을 둡니다.
struct Inspector: View {
    let model: LibraryModel
    /// 격자에 보이는 캡처입니다.
    let captures: [Capture]
    /// 화면이 설정 창에서 바꾼 값을 따라가도록 모델(`importFolder`)이 아니라 여기서 읽습니다.
    @AppStorage(SettingsKey.importFolder.rawValue)
    private var importPath = TransferItem.defaultImportFolder.path(percentEncoded: false)
    @AppStorage(SettingsKey.exportFolder.rawValue) private var exportPath: String?
    @AppStorage(SettingsKey.makesGameFolder.rawValue) private var makesGameFolder = true
    @AppStorage(SettingsKey.exportNaming.rawValue) private var naming = ExportNaming.original
    @State private var isChoosingImportFolder = false
    @State private var isChoosingExportFolder = false

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
        let newCount = model.index.newCaptures(captures, serialNumber: model.serialNumber ?? "").count
        let lastTransfer = model.index.lastTransfer(of: captures, serialNumber: model.serialNumber ?? "")
        // 가장 최근 캡처입니다.
        if let latest = captures.min(by: Capture.newestFirst) {
            Thumbnail(capture: latest)
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 8))
        }
        field(model.scope.title)
        properties("정보") {
            row("항목", Text("\(captures.count) (사진 \(summary.photoCount), 영상 \(summary.videoCount))"))
            row("크기", size(summary))
            if let first = summary.first, let last = summary.last {
                row("처음 찍은 날", Text(first, format: Date.FormatStyle(date: .numeric)))
                row("마지막 찍은 날", Text(last, format: Date.FormatStyle(date: .numeric)))
            }
            if let lastTransfer {
                row("지난번 옮긴 날", Text("\(lastTransfer.day, format: .dateTime.month().day()), \(lastTransfer.count)개"))
            } else {
                row("지난번 옮긴 날", Text("없음"))
            }
            GridRow {
                label("새 항목")
                HStack(spacing: 4) {
                    Text("\(newCount)개")
                    if newCount > 0 {
                        Text("새")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .background(Color.newCapture, in: .capsule)
                    }
                }
            }
        }
        Divider()
        folderButton("가져올 곳", path: Text(verbatim: importFolder.abbreviatedPath)) {
            isChoosingImportFolder = true
        }
        .fileImporter(isPresented: $isChoosingImportFolder, allowedContentTypes: [.folder]) { result in
            if case let .success(folder) = result {
                importPath = folder.path(percentEncoded: false)
            }
        }
        Button {} label: {
            Label("새 항목 \(newCount)개 가져오기", systemImage: "square.and.arrow.down")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(newCount == 0 || model.isDemo)
        Button {
            model.selection.selectAll(captures.map(\.id))
        } label: {
            Group {
                if case .game = model.scope {
                    Text("게임 전체 내보내기")
                } else {
                    Text("모두 내보내기")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .disabled(captures.isEmpty)
    }

    /// 게임을 보면 그 게임 폴더까지 보입니다. 다른 범위는 게임마다 폴더가 갈리므로 기준 폴더만 보입니다.
    private var importFolder: URL {
        let root = URL(filePath: importPath, directoryHint: .isDirectory)
        guard case let .game(name) = model.scope else { return root }
        return root.appending(path: name)
    }

    @ViewBuilder private func selectionInfo(_ selected: [Capture]) -> some View {
        let summary = CaptureSummary(selected)
        // 미리보기는 기준 폴더 이름을 보이지 않으므로, 기준 폴더를 고르기 전에도 아무 폴더로 만들어 봅니다.
        let options = ExportOptions(baseFolder: .temporaryDirectory, makesGameFolder: makesGameFolder, naming: naming)
        stack(Array(selected.prefix(3)))
        field(Text("\(selected.count)개 고름"))
        properties("고른 항목") {
            row("사진, 영상", Text("사진 \(summary.photoCount), 영상 \(summary.videoCount)"))
            row("크기", size(summary))
            if let first = summary.first, let last = summary.last {
                row("찍은 때", Text(captureRange(first, last)))
            }
        }
        Divider()
        folderButton(
            "내보낼 곳",
            path: exportPath.map { Text(verbatim: URL(filePath: $0).abbreviatedPath) } ?? Text("고르기…")
        ) {
            isChoosingExportFolder = true
        }
        Toggle("게임 이름 폴더 만들기", isOn: $makesGameFolder)
        Picker("파일 이름", selection: $naming) {
            Text("원래 이름 그대로").tag(ExportNaming.original)
            Text("찍은 순서대로 번호 붙이기").tag(ExportNaming.numbered)
        }
        Text(verbatim: ExportPreview.lines(TransferItem.exports(selected, options: options)).joined(separator: "\n"))
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.quaternary, in: .rect(cornerRadius: 8))
        Button {
            if model.exportOptions == nil {
                isChoosingExportFolder = true
            }
        } label: {
            Label("내보내기", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(model.isDemo)
        .fileImporter(isPresented: $isChoosingExportFolder, allowedContentTypes: [.folder]) { result in
            if case let .success(folder) = result {
                exportPath = folder.path(percentEncoded: false)
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

    /// 같은 날이면 시각까지, 여러 날에 걸치면 날짜만 씁니다.
    private func captureRange(_ first: Date, _ last: Date) -> String {
        Calendar.current.isDate(first, inSameDayAs: last)
            ? (first ..< last).formatted(.interval.month().day().hour().minute())
            : (first ..< last).formatted(.interval.month().day())
    }

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

    private func folderButton(_ title: LocalizedStringKey, path: Text, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    path
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
    }
}

extension URL {
    /// 홈 폴더를 `~`로 줄인 경로입니다.
    var abbreviatedPath: String {
        (path(percentEncoded: false) as NSString).abbreviatingWithTildeInPath
    }
}
