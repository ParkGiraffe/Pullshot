import PullshotKit
import SwiftUI

/// 기기를 열기 전까지 상세 칸에 두는 안내입니다. 기기가 없으면 PC로 복사 모드를 켜는 방법을 단계별로 보여 줍니다.
/// 옮기던 중 기기가 빠졌으면 그 결과를 맨 위에 남겨 둡니다.
struct ConnectionGuide: View {
    let model: LibraryModel

    var body: some View {
        VStack(spacing: 16) {
            if let summary = model.transferRun?.summary {
                transferResult(summary)
            }
            switch model.connection {
            case .searching:
                symbol("cable.connector")
                Text("스위치를 연결해 주세요")
                    .font(.title2.bold())
                steps([
                    "독이 아니라 본체 아래쪽 USB-C 포트에 데이터 케이블을 연결합니다.",
                    "본체 설정의 데이터 관리에서 PC로 복사를 켭니다.",
                ])
            case let .notInTransferMode(name):
                symbol("gamecontroller")
                Text("\(name)가 연결되어 있지만 PC로 복사 모드가 아닙니다.")
                    .font(.title3.bold())
                steps(["본체 설정의 데이터 관리에서 PC로 복사를 켭니다."])
            case .reattachNeeded:
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

    private func transferResult(_ summary: TransferSummary) -> some View {
        VStack(spacing: 6) {
            Text(TransferText.summary(summary))
                .font(.headline)
                .monospacedDigit()
            // 취소하지 않았는데 받지 못한 캡처가 남았다면 세션이 끊겨 멈춘 것입니다.
            if summary.notAttempted > 0, !summary.isCancelled {
                Text("연결이 끊겨 남은 사진과 동영상을 받지 못했습니다. 받지 못한 항목은 옮긴 기록에 넣지 않았으므로, 다시 연결하면 이어서 받을 수 있습니다.")
                    .foregroundStyle(.secondary)
            }
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
                    // fixedSize(vertical:)를 붙이면 창이 최소 높이를 잴 때 폭 0에서 잰 높이를 써서, 창이 화면 아래로 커집니다.
                    Text(steps[number])
                        .multilineTextAlignment(.leading)
                }
            }
        }
    }
}
