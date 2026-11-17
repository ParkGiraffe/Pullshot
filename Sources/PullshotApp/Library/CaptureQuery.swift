import Foundation
import PullshotKit

enum LibraryScope: Hashable {
    case all, new, videos, recentlyTransferred
    case game(String)
}

enum KindFilter {
    case all, photos, videos
}

enum EmptyReason {
    case allTransferred
    case noRecentTransfer
    case onlyPhotosShown
    case onlyVideosShown
}

struct CaptureQuery: Hashable {
    static let recentPeriod: TimeInterval = 30 * 86400

    var scope: LibraryScope
    var kind: KindFilter

    var shownKind: KindFilter {
        kind == .all && scope == .videos ? .videos : kind
    }

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
        let shown = switch kind {
        case .all: inScope
        case .photos: inScope.filter { $0.kind == .photo }
        case .videos: inScope.filter { $0.kind == .video }
        }
        return shown.sorted(by: Capture.newestFirst)
    }

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
