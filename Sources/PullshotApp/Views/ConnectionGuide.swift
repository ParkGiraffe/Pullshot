import SwiftUI

/// 기기를 열기 전까지 상세 칸에 두는 안내입니다. 기기가 없으면 PC로 복사 모드를 켜는 방법을 단계별로 보여 줍니다.
struct ConnectionGuide: View {
    let model: LibraryModel

    var body: some View {
        VStack(spacing: 16) {
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
                Text("\(name)가 연결돼 있지만 PC로 복사 모드가 아닙니다.")
                    .font(.title3.bold())
                steps(["본체 설정의 데이터 관리에서 PC로 복사를 켭니다."])
            case .reattachNeeded:
                symbol("arrow.triangle.2.circlepath")
                Text("남은 연결을 풀려고 스위치를 USB에서 다시 연결했습니다. 본체에서 PC로 복사를 다시 켜 주세요.")
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
                Button("다시 시도") {
                    Task { await model.retry() }
                }
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
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
