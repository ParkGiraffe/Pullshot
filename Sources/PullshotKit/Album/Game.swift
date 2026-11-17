import Foundation

public struct Game: Equatable, Sendable, Identifiable {
    public static let otherFolderName = "기타"

    public var name: String
    public var captures: [Capture]

    public var id: String {
        name
    }

    public var isOther: Bool {
        name == Self.otherFolderName
    }

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
    var gameName: String {
        gameFolder ?? Game.otherFolderName
    }
}
