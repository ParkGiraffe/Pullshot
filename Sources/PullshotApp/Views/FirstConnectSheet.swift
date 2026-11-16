import PullshotKit
import SwiftUI

/// 기록이 빈 스위치를 처음 열면, 이미 Mac에 받아 둔 캡처를 옮긴 기록에 넣을지 묻습니다.
/// "나중에"로 닫으면 답하지 않은 것이라 다음 연결에서 다시 묻습니다.
struct FirstConnectSheet: View {
    let model: LibraryModel
    @State private var isChoosingFolder = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("이미 받아 둔 캡처가 있나요?")
                .font(.title3.bold())
            Text("처음 연결한 스위치입니다. 이미 Mac에 받아 둔 캡처를 옮긴 기록에 넣으면, 그 캡처는 새 항목에 나오지 않습니다.")
                .fixedSize(horizontal: false, vertical: true)
            if let count = model.firstConnectRecordedCount {
                Text("기록에 넣은 캡처 \(count)개")
                    .font(.headline)
                HStack {
                    Spacer()
                    Button("확인") {
                        model.isAskingFirstConnect = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            } else if model.isAnsweringFirstConnect {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                    Button("취소", action: model.cancelFirstConnectAnswer)
                        .keyboardShortcut(.cancelAction)
                }
            } else {
                choices
            }
        }
        .padding(20)
        .frame(width: 460)
        .fileImporter(isPresented: $isChoosingFolder, allowedContentTypes: [.folder]) { result in
            if case let .success(folder) = result {
                model.answerFirstConnect(.findInFolder(folder))
            }
        }
        .onDisappear(perform: model.cancelFirstConnectAnswer)
    }

    @ViewBuilder private var choices: some View {
        if let errorMessage = model.firstConnectErrorMessage {
            Text(errorMessage)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
        VStack(spacing: 8) {
            Button {
                isChoosingFolder = true
            } label: {
                Text("폴더에서 찾기…")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Button {
                model.answerFirstConnect(.markAll)
            } label: {
                Text("지금 있는 캡처를 모두 옮긴 것으로 표시")
                    .frame(maxWidth: .infinity)
            }
            Button {
                model.answerFirstConnect(.leaveAllNew)
            } label: {
                Text("모두 새 항목으로 두기")
                    .frame(maxWidth: .infinity)
            }
        }
        .controlSize(.large)
        HStack {
            Spacer()
            Button("나중에") {
                model.isAskingFirstConnect = false
            }
            .keyboardShortcut(.cancelAction)
        }
    }
}
