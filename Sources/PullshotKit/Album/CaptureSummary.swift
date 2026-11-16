import Foundation

/// 캡처 여러 개의 수, 크기, 찍은 기간입니다. 툴바 부제와 오른쪽 칸 정보에 씁니다.
public struct CaptureSummary: Equatable, Sendable {
    public var photoCount: Int
    public var videoCount: Int
    /// 크기를 아는 캡처의 합입니다.
    public var totalSize: UInt64
    /// 가장 먼저 찍은 때입니다. 찍은 시각을 아는 캡처가 없으면 nil입니다.
    public var first: Date?
    /// 가장 나중에 찍은 때입니다. 찍은 시각을 아는 캡처가 없으면 nil입니다.
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
