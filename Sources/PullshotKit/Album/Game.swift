import Foundation

/// 앨범 폴더 하나, 곧 게임 하나의 캡처입니다.
public struct Game: Equatable, Sendable, Identifiable {
    /// 게임 폴더 밖의 캡처를 묶는 이름이자 가져올 때 만드는 폴더 이름입니다. 스위치에도 같은 이름의 폴더가 있어
    /// (펌웨어 23.5.0) 둘을 하나로 묶습니다. 이미 받은 파일과 이어지도록 언어와 관계없이 이 이름을 쓰고,
    /// 화면에 보일 이름은 앱과 CLI가 정합니다.
    public static let otherFolderName = "기타"

    public var name: String
    /// 최근 것이 먼저입니다.
    public var captures: [Capture]

    public var id: String {
        name
    }

    /// 게임 폴더 밖의 캡처와 스위치의 "기타" 폴더 캡처를 묶은 것인지입니다.
    public var isOther: Bool {
        name == Self.otherFolderName
    }

    /// 최근 캡처 순이고, 찍은 시각을 모르는 캡처만 있는 게임이 그다음, 기타가 맨 끝입니다.
    public static func games(in captures: [Capture]) -> [Self] {
        Dictionary(grouping: captures, by: \.gameName)
            .map { name, captures in Self(name: name, captures: captures.sorted(by: Capture.newestFirst)) }
            .sorted { lhs, rhs in
                guard lhs.isOther == rhs.isOther else { return rhs.isOther }
                return Capture.newestFirst(lhs.captures[0], rhs.captures[0])
            }
    }
}

public extension Capture {
    /// 게임을 가르고 가져올 곳의 폴더 이름으로 쓰는 게임 이름입니다. 옮긴 기록의 키에는 원래 `gameFolder`를 씁니다.
    var gameName: String {
        gameFolder ?? Game.otherFolderName
    }
}
