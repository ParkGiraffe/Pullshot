import SwiftUI

/// 설정 창입니다. 가져올 곳과 자세한 로그를 둡니다. 자세한 로그는 다음 연결부터 씁니다.
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
}
