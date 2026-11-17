import Foundation

public struct CaptureSummary: Equatable, Sendable {
    public var photoCount: Int
    public var videoCount: Int
    public var totalSize: UInt64
    public var first: Date?
    public var last: Date?

    public init(_ captures: [Capture]) {
        let dates = captures.compactMap(\.capturedAt)
        photoCount = captures.count { $0.kind == .photo }
        videoCount = captures.count { $0.kind == .video }
        totalSize = captures.reduce(0) { $0 + ($1.size ?? 0) }
        first = dates.min()
        last = dates.max()
    }
}
