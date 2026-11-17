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

/// 격자가 빈 까닭입니다. 빈 화면의 둘째 줄을 고릅니다.
enum EmptyReason {
    /// 새 항목을 모두 옮겼습니다.
    case allTransferred
    /// 최근 30일 동안 옮긴 캡처가 없습니다.
    case noRecentTransfer
    /// 필터로 사진만 보고 있어 동영상이 가려졌습니다.
    case onlyPhotosShown
    /// 필터로 동영상만 보고 있어 사진이 가려졌습니다.
    case onlyVideosShown
}

/// 격자에 보일 캡처를 가르는 규칙입니다.
struct CaptureQuery: Hashable {
    /// 최근 옮긴 항목으로 치는 기간입니다.
    static let recentPeriod: TimeInterval = 30 * 86400

    var scope: LibraryScope
    var kind: KindFilter

    /// 보이는 캡처의 종류입니다. 필터가 모두일 때 사이드바 동영상 범위는 동영상만 보입니다.
    var shownKind: KindFilter {
        kind == .all && scope == .videos ? .videos : kind
    }

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

    /// 보일 캡처가 없을 때 그 까닭입니다. 필터를 빼도 비었으면 사이드바에서 고른 범위 때문이고, 아니면 필터 때문입니다.
    /// 앨범이나 게임이 빈 것처럼 따로 알릴 까닭이 없으면 nil입니다.
    func emptyReason(in captures: [Capture], index: LedgerIndex, serialNumber: String, now: Date) -> EmptyReason? {
        let isScopeEmpty = Self(scope: scope, kind: .all)
            .captures(in: captures, index: index, serialNumber: serialNumber, now: now)
            .isEmpty
        if !isScopeEmpty {
            return kind == .photos ? .onlyPhotosShown : .onlyVideosShown
        }
        return switch scope {
        case .new: .allTransferred
        case .recentlyTransferred: .noRecentTransfer
        case .all, .videos, .game: nil
        }
    }
}
