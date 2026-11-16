import PullshotKit
import SwiftUI

extension LibraryScope {
    /// 툴바 제목입니다.
    var title: Text {
        switch self {
        case .all: Text("모든 항목")
        case .new: Text("새 항목")
        case .videos: Text("영상")
        case .recentlyTransferred: Text("최근 옮긴 항목")
        case let .game(name): Text(verbatim: name)
        }
    }
}

/// 기기 칸 아래 보기 범위 목록입니다. 고정 항목, 게임 목록, 게임 찾기 칸 순서입니다.
struct Sidebar: View {
    @Bindable var model: LibraryModel

    private var games: [Game] {
        let games = Game.games(in: model.captures)
        guard !model.gameSearch.isEmpty else { return games }
        return games.filter { $0.name.localizedStandardContains(model.gameSearch) }
    }

    var body: some View {
        VStack(spacing: 0) {
            DeviceSwitcher(model: model)
                .padding(.horizontal, 10)
            if case .ready = model.connection {
                list
            } else {
                Spacer(minLength: 0)
            }
        }
    }

    private var list: some View {
        List(selection: Binding(get: { model.scope }, set: { model.scope = $0 ?? .all })) {
            pinnedRow("모든 항목", icon: "square.grid.2x2", scope: .all)
            pinnedRow("새 항목", icon: "tray.and.arrow.down", scope: .new)
            pinnedRow("영상", icon: "video", scope: .videos)
            pinnedRow("최근 옮긴 항목", icon: "clock", scope: .recentlyTransferred)
            Section("게임 (\(Game.games(in: model.captures).count))") {
                ForEach(games) { game in
                    gameRow(game)
                }
                if games.isEmpty {
                    Text("찾는 게임이 없습니다")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease")
                    .foregroundStyle(.secondary)
                TextField("게임 이름으로 찾기", text: $model.gameSearch)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(.quaternary, in: .rect(cornerRadius: 7))
            .padding(10)
        }
    }

    private func count(_ scope: LibraryScope) -> Int {
        CaptureQuery(scope: scope, kind: .all)
            .captures(in: model.captures, index: model.index, serialNumber: model.serialNumber ?? "", now: .now).count
    }

    private func pinnedRow(_ title: LocalizedStringKey, icon: String, scope: LibraryScope) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            if scope == .new, count(.new) > 0 {
                Text(count(.new), format: .number)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .background(Color.newCapture, in: .capsule)
            } else {
                Text(count(scope), format: .number)
                    .foregroundStyle(.secondary)
            }
        }
        .tag(scope)
    }

    private func gameRow(_ game: Game) -> some View {
        HStack(spacing: 8) {
            Thumbnail(capture: game.captures[0])
                .frame(width: 22, height: 22)
                .clipShape(.rect(cornerRadius: 6))
                .overlay(alignment: .topTrailing) {
                    if !model.index.newCaptures(game.captures, serialNumber: model.serialNumber ?? "").isEmpty {
                        Circle()
                            .fill(Color.newCapture)
                            .frame(width: 7, height: 7)
                            .offset(x: 3, y: -3)
                    }
                }
            Text(verbatim: game.name)
                .lineLimit(2)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            Text(game.captures.count, format: .number)
                .foregroundStyle(.secondary)
        }
        .tag(LibraryScope.game(game.name))
    }
}
