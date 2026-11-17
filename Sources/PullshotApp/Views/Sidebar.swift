import PullshotKit
import SwiftUI

extension LibraryScope {
    /// 툴바 제목입니다.
    var title: Text {
        switch self {
        case .all: Text("모든 항목")
        case .new: Text("새 항목")
        case .videos: Text("동영상")
        case .recentlyTransferred: Text("최근 옮긴 항목")
        case let .game(name): Text(verbatim: gameTitle(name))
        }
    }
}

/// Kit은 기타 묶음을 가져올 폴더 이름으로 부르므로, 화면에는 문자열 표의 이름을 보입니다.
private func gameTitle(_ name: String) -> String {
    name == Game.otherFolderName ? String(localized: "기타") : name
}

/// 기기 칸 아래 보기 범위 목록입니다. 고정 항목, 게임 목록, 게임 찾기 칸 순서입니다.
struct Sidebar: View {
    @Bindable var model: LibraryModel

    var body: some View {
        VStack(spacing: 0) {
            DeviceSwitcher(model: model)
                .padding(.horizontal, 10)
            if case .ready = model.connection {
                list
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .foregroundStyle(.secondary)
                    TextField("폴더 이름으로 찾기", text: $model.gameSearch)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(.quaternary, in: .rect(cornerRadius: 7))
                .padding(10)
            } else {
                Spacer(minLength: 0)
            }
        }
    }

    private var list: some View {
        let serialNumber = model.serialNumber ?? ""
        let allGames = Game.games(in: model.captures)
        let newIDs = Set(model.index.newCaptures(model.captures, serialNumber: serialNumber).map(\.id))
        let shownGames = model.gameSearch.isEmpty
            ? allGames
            : allGames.filter { gameTitle($0.name).localizedStandardContains(model.gameSearch) }
        func count(_ scope: LibraryScope) -> Int {
            CaptureQuery(scope: scope, kind: .all)
                .captures(in: model.captures, index: model.index, serialNumber: serialNumber, now: .now).count
        }
        return List(selection: Binding(get: { model.scope }, set: { model.show($0 ?? .all) })) {
            pinnedRow("모든 항목", icon: "square.grid.2x2", scope: .all, count: model.captures.count)
            pinnedRow("새 항목", icon: "tray.and.arrow.down", scope: .new, count: newIDs.count)
            pinnedRow("동영상", icon: "video", scope: .videos, count: count(.videos))
            pinnedRow("최근 옮긴 항목", icon: "clock", scope: .recentlyTransferred, count: count(.recentlyTransferred))
            Section("폴더 (\(allGames.count))") {
                ForEach(shownGames) { game in
                    gameRow(game, hasNew: game.captures.contains { newIDs.contains($0.id) })
                }
                if shownGames.isEmpty {
                    Text("찾는 폴더가 없습니다")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func pinnedRow(_ title: LocalizedStringKey, icon: String, scope: LibraryScope, count: Int) -> some View {
        HStack {
            Label {
                Text(title)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(Color.pullshotAccent)
            }
            Spacer()
            Text(count, format: .number)
                .foregroundStyle(.secondary)
        }
        .tag(scope)
    }

    private func gameRow(_ game: Game, hasNew: Bool) -> some View {
        HStack(spacing: 8) {
            Thumbnail(capture: game.captures[0])
                .frame(width: 22, height: 22)
                .clipShape(.rect(cornerRadius: 6))
                .overlay(alignment: .topTrailing) {
                    if hasNew {
                        Circle()
                            .fill(Color.newCapture)
                            .frame(width: 7, height: 7)
                            .offset(x: 3, y: -3)
                    }
                }
            Text(verbatim: gameTitle(game.name))
                .lineLimit(2)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            Text(game.captures.count, format: .number)
                .foregroundStyle(.secondary)
        }
        .tag(LibraryScope.game(game.name))
    }
}
