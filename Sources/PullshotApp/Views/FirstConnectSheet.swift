import PullshotKit
import SwiftUI

/// 기록이 빈 스위치를 처음 열면, 이미 Mac에 받아 둔 캡처를 옮긴 기록에 넣을지 묻습니다.
/// "나중에"로 닫으면 답하지 않은 것이라 다음 연결에서 다시 묻습니다.
struct FirstConnectSheet: View {
    let model: LibraryModel
    @State private var isChoosingFolder = false
    /// 답을 기록에 남기는 작업입니다. 폴더에서 찾기는 폴더가 크면 오래 걸려 취소할 수 있게 둡니다.
    @State private var answering: Task<Void, Never>?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("이미 받아 둔 캡처가 있나요?")
                .font(.title3.bold())
            Text("처음 연결한 스위치입니다. 지금 있는 캡처가 모두 새 항목으로 보이지 않도록, 이미 Mac에 받아 둔 캡처를 옮긴 기록에 넣을 수 있습니다.")
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
            } else if answering != nil {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                    Button("취소") {
                        answering?.cancel()
                    }
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
                answer(.findInFolder(folder))
            }
        }
        .onDisappear {
            answering?.cancel()
        }
    }

    @ViewBuilder private var choices: some View {
        if let errorMessage {
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
                answer(.markAll)
            } label: {
                Text("지금 있는 캡처를 모두 옮긴 것으로 표시")
                    .frame(maxWidth: .infinity)
            }
            Button {
                answer(.leaveAllNew)
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

    private func answer(_ answer: FirstConnectAnswer) {
        errorMessage = nil
        answering = Task {
            errorMessage = await model.answerFirstConnect(answer)
            answering = nil
        }
    }
}
