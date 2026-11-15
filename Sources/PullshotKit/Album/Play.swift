import Foundation

/// 같은 게임에서 캡처 사이가 `maxGap`을 넘게 비지 않은 한 번의 묶음입니다. 앉아서 한 번 플레이한 단위로 봅니다.
public struct Play: Equatable, Sendable {
    /// 캡처 사이가 이보다 길게 비면 다른 플레이입니다(설계 6.2).
    public static let maxGap: TimeInterval = 60 * 60

    /// 찍은 순서(오래된 것 먼저)입니다. 연재 글을 쓰는 순서와 같습니다.
    public var captures: [Capture]

    public var start: Date? {
        captures.first?.capturedAt
    }

    public var end: Date? {
        captures.last?.capturedAt
    }

    public var photoCount: Int {
        captures.count { $0.kind == .photo }
    }

    public var videoCount: Int {
        captures.count { $0.kind == .video }
    }

    /// 최근 플레이가 먼저입니다. 찍은 시각을 모르는 캡처는 파일 이름 순으로 마지막 플레이 하나에 모읍니다.
    public static func split(_ captures: [Capture]) -> [Self] {
        let dated = captures
            .compactMap { capture in capture.capturedAt.map { (date: $0, capture: capture) } }
            .sorted { ($0.date, $0.capture.filename) < ($1.date, $1.capture.filename) }
        var groups: [[Capture]] = []
        var previous: Date?
        for (date, capture) in dated {
            if let previous, date.timeIntervalSince(previous) <= maxGap {
                groups[groups.count - 1].append(capture)
            } else {
                groups.append([capture])
            }
            previous = date
        }
        let undated = captures.filter { $0.capturedAt == nil }.sorted { $0.filename < $1.filename }

        return (groups.reversed() + (undated.isEmpty ? [] : [undated])).map { Self(captures: $0) }
    }
}
