import SwiftUI

/// 설정 창입니다. 가져올 곳, 앱 아이콘, 자세한 로그를 둡니다. 자세한 로그는 다음 연결부터 씁니다.
struct SettingsView: View {
    @Bindable var settings: AppSettings
    @State private var isChoosingImportFolder = false

    var body: some View {
        Form {
            LabeledContent("가져올 곳") {
                HStack {
                    Text(verbatim: settings.importFolder.abbreviatedPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("바꾸기…") {
                        isChoosingImportFolder = true
                    }
                }
            }
            LabeledContent {
                HStack(spacing: 10) {
                    ForEach(AppIcon.allCases, id: \.self, content: iconButton)
                }
            } label: {
                Text("앱 아이콘")
                Text("앱이 열려 있는 동안 Dock에 보이는 아이콘만 바뀌고, Finder에 보이는 앱 아이콘은 그대로입니다.")
            }
            Toggle(isOn: $settings.isVerboseLog) {
                Text("자세한 로그 남기기")
                Text("스위치와 주고받은 내용을 로그 파일에 한 줄씩 남깁니다. 문제를 알릴 때만 켜 주세요.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .fileImporter(isPresented: $isChoosingImportFolder, allowedContentTypes: [.folder]) { result in
            if case let .success(folder) = result {
                settings.importFolder = folder
            }
        }
    }

    /// Finder에서 고른 아이콘처럼 그림 뒤에 옅은 바탕을, 이름에 강조색 바탕을 깝니다.
    private func iconButton(_ icon: AppIcon) -> some View {
        let isChosen = settings.appIcon == icon
        return Button {
            settings.appIcon = icon
            icon.showInDock()
        } label: {
            VStack(spacing: 3) {
                Image(nsImage: icon.image ?? NSImage())
                    .resizable()
                    .frame(width: 44, height: 44)
                    .padding(3)
                    .background(
                        isChosen ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
                        in: .rect(cornerRadius: 8)
                    )
                Text(title(of: icon))
                    .font(.caption)
                    .foregroundStyle(isChosen ? Color.white : Color.primary)
                    .padding(.horizontal, 6)
                    .background(isChosen ? Color.pullshotAccent : .clear, in: .capsule)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    private func title(of icon: AppIcon) -> LocalizedStringKey {
        switch icon {
        case .red: "빨강"
        case .purple: "보라"
        case .shutter: "셔터 프레임"
        }
    }
}
