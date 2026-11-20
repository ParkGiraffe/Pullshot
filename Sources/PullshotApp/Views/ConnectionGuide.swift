import PullshotKit
import SwiftUI

struct ConnectionGuide: View {
    let model: LibraryModel

    var body: some View {
        VStack(spacing: 16) {
            if let summary = model.transferRun?.summary, summary.notAttempted > 0, !summary.isCancelled {
                interruptedTransfer(summary)
            }
            switch model.connection {
            case .noConsole:
                symbol("cable.connector")
                Text("스위치를 연결해 주세요")
                    .font(.title2.bold())
                steps([
                    "독이 아니라 본체 아래쪽 USB-C 포트에 데이터 케이블을 연결합니다.",
                    "본체의 설정 > 데이터 관리 > 화면 사진과 동영상 관리에서 PC로 복사를 켭니다.",
                ])
            case let .notInTransferMode(name):
                symbol("gamecontroller")
                Text("\(name)가 연결되어 있지만 PC로 복사 모드가 아닙니다.")
                    .font(.title3.bold())
                steps(["본체의 설정 > 데이터 관리 > 화면 사진과 동영상 관리에서 PC로 복사를 켭니다."])
            case .usbReset:
                symbol("arrow.triangle.2.circlepath")
                Text("이전 연결이 남아 있어 스위치의 USB 연결을 재설정했고, 이때 PC로 복사가 꺼졌습니다. 본체에서 PC로 복사를 다시 켜 주세요.")
                    .font(.title3)
            case .connecting:
                ProgressView()
                Text("연결하는 중")
                    .foregroundStyle(.secondary)
            case let .scanning(_, seen):
                ProgressView()
                Text("앨범을 읽는 중 · \(seen)개")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            case let .failed(_, message):
                symbol("exclamationmark.triangle")
                Text(message)
                    .font(.title3)
                Button("다시 시도", action: model.retry)
                    .buttonStyle(.borderedProminent)
            case .ready:
                EmptyView()
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: 420)
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func interruptedTransfer(_ summary: TransferSummary) -> some View {
        VStack(spacing: 6) {
            Text(TransferText.summary(summary))
                .font(.headline)
                .monospacedDigit()
            Text("연결이 끊겨 남은 사진과 동영상을 가져오지 못했습니다. 다시 연결하면 이어서 가져올 수 있습니다.")
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.quaternary, in: .rect(cornerRadius: 8))
    }

    private func symbol(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 40))
            .foregroundStyle(.secondary)
    }

    private func steps(_ steps: [LocalizedStringKey]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(steps.indices, id: \.self) { number in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(number + 1, format: .number)
                        .font(.callout.bold())
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Color.pullshotAccent, in: .circle)
                    Text(steps[number])
                        .multilineTextAlignment(.leading)
                }
            }
        }
    }
}
