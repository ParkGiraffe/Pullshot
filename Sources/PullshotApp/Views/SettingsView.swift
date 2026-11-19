import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @State private var isChoosingImportFolder = false

    var body: some View {
        Form {
            Picker(selection: $settings.language) {
                Text("시스템 언어").tag(AppLanguage.system)
                Text(verbatim: "English").tag(AppLanguage.english)
                Text(verbatim: "한국어").tag(AppLanguage.korean)
            } label: {
                Text("언어")
                Text("앱을 다시 열면 적용됩니다.")
            }
            LabeledContent("저장 위치") {
                HStack {
                    Text(verbatim: settings.importFolder.abbreviatedPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("변경…") {
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
                Text("앱이 실행 중일 때 Dock 아이콘만 바뀌고, Finder의 앱 아이콘은 그대로입니다.")
            }
            Toggle(isOn: $settings.shouldCheckForUpdates) {
                Text("업데이트 자동 확인")
                Text("앱을 켤 때 GitHub에서 새 버전이 있는지 확인합니다. 앱 메뉴의 업데이트 확인에서 직접 확인할 수도 있습니다.")
            }
            Toggle(isOn: $settings.isVerboseLogging) {
                Text("자세한 로그 남기기")
                Text("스위치와 통신하는 과정을 로그 파일에 한 줄씩 기록하며, 켜는 즉시 지금 연결에도 적용됩니다. 문제를 알릴 때만 켜 주세요.")
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
