import Foundation

public struct Capture: Equatable, Sendable, Identifiable {
    public enum Kind: Sendable {
        case photo
        case video
    }

    public var handle: UInt32
    public var storageID: UInt32
    public var filename: String
    public var size: UInt64?
    public var capturedAt: Date?
    public var kind: Kind
    public var gameFolder: String?

    public init(
        handle: UInt32,
        storageID: UInt32,
        filename: String,
        size: UInt64?,
        capturedAt: Date?,
        kind: Kind,
        gameFolder: String?
    ) {
        self.handle = handle
        self.storageID = storageID
        self.filename = filename
        self.size = size
        self.capturedAt = capturedAt
        self.kind = kind
        self.gameFolder = gameFolder
    }

    public var id: String {
        "\(gameFolder ?? "")/\(filename)"
    }

    public static func isSafeFilename(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/") && !name.contains("\0")
    }

    public static func oldestFirst(_ lhs: Self, _ rhs: Self) -> Bool {
        switch (lhs.capturedAt, rhs.capturedAt) {
        case let (left?, right?) where left != right:
            left < right
        case (.some, nil):
            true
        case (nil, .some):
            false
        default:
            lhs.filename < rhs.filename
        }
    }

    public static func newestFirst(_ lhs: Self, _ rhs: Self) -> Bool {
        switch (lhs.capturedAt, rhs.capturedAt) {
        case let (left?, right?) where left != right:
            left > right
        case (.some, nil):
            true
        case (nil, .some):
            false
        default:
            lhs.filename < rhs.filename
        }
    }
}
