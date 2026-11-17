import Foundation

public struct CaptureSummary: Equatable, Sendable {
    public var photoCount: Int
    public var videoCount: Int
    public var totalSize: UInt64
    public var firstCapturedAt: Date?
    public var lastCapturedAt: Date?

    public init(_ captures: [Capture]) {
        let dates = captures.compactMap(\.capturedAt)
        photoCount = captures.count { $0.kind == .photo }
        videoCount = captures.count { $0.kind == .video }
        totalSize = captures.reduce(0) { $0 + ($1.size ?? 0) }
        firstCapturedAt = dates.min()
        lastCapturedAt = dates.max()
    }
}
