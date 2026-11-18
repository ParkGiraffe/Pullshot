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
    var kindFilter: KindFilter

    var shownKind: KindFilter {
        kindFilter == .all && scope == .videos ? .videos : kindFilter
    }

    func captures(in captures: [Capture], ledgerIndex: LedgerIndex, serialNumber: String, now: Date) -> [Capture] {
        let inScope = switch scope {
        case .all:
            captures
        case .new:
            ledgerIndex.newCaptures(captures, serialNumber: serialNumber)
        case .videos:
            captures.filter { $0.kind == .video }
        case .recentlyTransferred:
            ledgerIndex.recentlyTransferred(
                captures,
                serialNumber: serialNumber,
                since: now.addingTimeInterval(-Self.recentPeriod)
            )
        case let .game(name):
            captures.filter { $0.gameName == name }
        }
        let shown = switch kindFilter {
        case .all: inScope
        case .photos: inScope.filter { $0.kind == .photo }
        case .videos: inScope.filter { $0.kind == .video }
        }
        return shown.sorted(by: Capture.newestFirst)
    }

    func emptyReason(
        in captures: [Capture],
        ledgerIndex: LedgerIndex,
        serialNumber: String,
        now: Date
    ) -> EmptyReason? {
        guard !captures.isEmpty else { return nil }
        let isScopeEmpty = Self(scope: scope, kindFilter: .all)
            .captures(in: captures, ledgerIndex: ledgerIndex, serialNumber: serialNumber, now: now)
            .isEmpty
        if !isScopeEmpty {
            return kindFilter == .photos ? .onlyPhotosShown : .onlyVideosShown
        }
        return switch scope {
        case .new: .allTransferred
        case .recentlyTransferred: .noRecentTransfer
        case .all, .videos, .game: nil
        }
    }
}
