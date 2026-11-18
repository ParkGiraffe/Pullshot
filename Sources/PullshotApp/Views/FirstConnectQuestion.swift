import PullshotKit
import SwiftUI

struct FirstConnectQuestion: View {
    let model: LibraryModel
    @State private var isChoosingFolder = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Mac에 이미 저장한 사진과 동영상이 있나요?")
                .font(.title3.bold())
            Text("처음 연결한 스위치입니다. Mac에 이미 저장한 사진과 동영상을 가져온 기록에 추가하면 새 항목에 표시되지 않습니다.")
                .fixedSize(horizontal: false, vertical: true)
            if let count = model.firstConnectRecordedCount {
                Text("기록에 추가한 사진과 동영상 \(count)개")
                    .font(.headline)
                HStack {
                    Spacer()
                    Button("확인") {
                        model.isFirstConnectQuestionShown = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            } else if model.isRecordingFirstConnectAnswer {
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
        .frame(maxWidth: 460)
        .background(.regularMaterial, in: .rect(cornerRadius: 12))
        .shadow(radius: 16)
        .padding()
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
                Text("스위치에 있는 사진과 동영상을 모두 가져온 것으로 표시")
                    .frame(maxWidth: .infinity)
            }
            Button {
                model.answerFirstConnect(.leaveAllNew)
            } label: {
                Text("모두 새 항목으로 유지")
                    .frame(maxWidth: .infinity)
            }
        }
        .controlSize(.large)
        HStack {
            Spacer()
            Button("나중에") {
                model.isFirstConnectQuestionShown = false
            }
            .keyboardShortcut(.cancelAction)
        }
    }
}
