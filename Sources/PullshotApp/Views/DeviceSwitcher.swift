import PullshotKit
import SwiftUI

/// 사이드바 위 기기 칸입니다. 연 기기와 연결 상태를 보이고, 스위치가 둘 이상 꽂히면 바꿀 수 있습니다.
struct DeviceSwitcher: View {
    let model: LibraryModel

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "gamecontroller")
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.pullshotAccent, in: .rect(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 2) {
                if let console = model.connection.console {
                    Text(name(of: console))
                        .font(.headline)
                        .truncationMode(.middle)
                } else {
                    Text("스위치")
                        .font(.headline)
                }
                status
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if model.connection.console?.model.isExperimental == true {
                    Text("실험적 지원")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(.quaternary, in: .capsule)
                        .help("확인하지 못한 기기입니다. 문제가 있으면 설정에서 자세한 로그를 켜고 다시 해 본 뒤, 로그 파일과 함께 GitHub 이슈로 알려 주세요.")
                }
            }
            .lineLimit(1)
            Spacer(minLength: 0)
            if model.consoles.count > 1 {
                Menu {
                    ForEach(model.consoles, id: \.registryID) { console in
                        Button(name(of: console)) {
                            model.choose(console)
                        }
                    }
                } label: {
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundStyle(.tertiary)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .disabled(model.isTransferring)
            }
        }
        .padding(8)
    }

    @ViewBuilder private var status: some View {
        switch model.connection {
        case let .ready(_, info):
            HStack(spacing: 4) {
                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)
                Text("연결됨 · \(info.deviceVersion)")
            }
        case .connecting, .scanning:
            Text("연결하는 중")
        case .failed:
            Text("연결하지 못함")
        case .searching, .notInTransferMode, .reattachNeeded:
            Text("연결된 스위치 없음")
        }
    }

    /// 같은 이름의 스위치가 둘 이상 꽂혀 있으면 USB 일련번호 끝 네 자리로 가립니다.
    private func name(of console: AttachedConsole) -> String {
        let name = console.model.name
        guard model.consoles.count(where: { $0.model.name == name }) > 1, let serialNumber = console.serialNumber else {
            return name
        }
        return "\(name) (\(serialNumber.suffix(4)))"
    }
}
