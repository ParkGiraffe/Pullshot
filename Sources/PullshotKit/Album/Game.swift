import Foundation

/// 앨범 폴더 하나, 곧 게임 하나의 캡처입니다.
public struct Game: Equatable, Sendable, Identifiable {
    /// 게임 폴더 밖의 캡처를 묶는 이름입니다. 스위치에도 같은 이름의 폴더가 있어(펌웨어 23.5.0) 둘을 하나로 묶습니다.
    public static let otherName = "기타"

    public var name: String
    /// 최근 것이 먼저입니다.
    public var captures: [Capture]

    public var id: String {
        name
    }

    /// 최근 캡처 순이고, 찍은 시각을 모르는 캡처만 있는 게임이 그다음, 기타가 맨 끝입니다.
    public static func games(in captures: [Capture]) -> [Self] {
        Dictionary(grouping: captures, by: \.gameName)
            .map { name, captures in Self(name: name, captures: captures.sorted(by: Capture.newestFirst)) }
            .sorted { lhs, rhs in
                guard (lhs.name == otherName) == (rhs.name == otherName) else { return rhs.name == otherName }
                return Capture.newestFirst(lhs.captures[0], rhs.captures[0])
            }
    }
}

public extension Capture {
    /// 화면과 가져올 곳에 쓰는 게임 이름입니다. 기록의 열쇠에는 원래 `gameFolder`를 씁니다.
    var gameName: String {
        gameFolder ?? Game.otherName
    }
}
