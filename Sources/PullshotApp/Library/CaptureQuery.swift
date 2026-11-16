import Foundation
import PullshotKit

/// 사이드바에서 고른 보기 범위입니다.
enum LibraryScope: Hashable {
    case all, new, videos, recentlyTransferred
    case game(String)
}

/// 툴바 필터 메뉴에서 고른 종류입니다.
enum KindFilter {
    case all, photos, videos
}

/// 격자에 보일 캡처를 가르는 규칙입니다.
struct CaptureQuery {
    /// 최근 옮긴 항목으로 치는 기간입니다.
    static let recentPeriod: TimeInterval = 30 * 86400

    var scope: LibraryScope
    var kind: KindFilter

    /// 입력 순서를 지킵니다.
    func captures(in captures: [Capture], index: LedgerIndex, serialNumber: String, now: Date) -> [Capture] {
        let inScope = switch scope {
        case .all:
            captures
        case .new:
            index.newCaptures(captures, serialNumber: serialNumber)
        case .videos:
            captures.filter { $0.kind == .video }
        case .recentlyTransferred:
            index.recentlyTransferred(
                captures,
                serialNumber: serialNumber,
                since: now.addingTimeInterval(-Self.recentPeriod)
            )
        case let .game(name):
            captures.filter { $0.gameName == name }
        }
        return switch kind {
        case .all: inScope
        case .photos: inScope.filter { $0.kind == .photo }
        case .videos: inScope.filter { $0.kind == .video }
        }
    }
}
