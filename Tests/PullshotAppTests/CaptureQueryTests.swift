import Foundation
import PullshotKit
import Testing
@testable import PullshotApp

@Suite("CaptureQuery 테스트")
struct CaptureQueryTests {
    let ledger: TransferLedger

    init() throws {
        ledger = try TransferLedger(directory: temporaryFolderFixture())
    }

    @Test func `새 항목 범위는 기록에 없는 캡처만 보인다`() throws {
        let (old, new) = (captureFixture("a.jpg"), captureFixture("b.jpg"))
        try ledger.record([old], serialNumber: "S1", as: .imported)
        #expect(CaptureQuery(scope: .new, kind: .all)
            .captures(in: [new, old], index: ledger.index, serialNumber: "S1", now: .now).map(\.filename) == ["b.jpg"])
    }

    @Test func `최근 옮긴 항목은 30일 안에 가져오거나 내보낸 캡처다`() throws {
        let (a, b) = (captureFixture("a.jpg"), captureFixture("b.jpg"))
        try ledger.record([a], serialNumber: "S1", as: .imported, at: dateFixture("2026-10-16 23:59:59"))
        try ledger.record([b], serialNumber: "S1", as: .exported, at: dateFixture("2026-10-17 00:00:00"))
        let now = dateFixture("2026-11-16 00:00:00")
        #expect(CaptureQuery(scope: .recentlyTransferred, kind: .all)
            .captures(in: [a, b], index: ledger.index, serialNumber: "S1", now: now).map(\.filename) == ["b.jpg"])
    }

    @Test func `게임 범위에 영상 필터를 더하면 그 게임의 영상만 보인다`() {
        let captures = [
            captureFixture("a.mp4", kind: .video),
            captureFixture("b.jpg"),
            captureFixture("c.mp4", game: "마리오 카트 월드", kind: .video),
        ]
        #expect(CaptureQuery(scope: .game("젤다무쌍 봉인전기"), kind: .videos)
            .captures(in: captures, index: LedgerIndex(), serialNumber: "S1", now: .now).map(\.filename) == ["a.mp4"])
    }

    @Test func `기타 범위는 폴더 밖 캡처와 기타 폴더 캡처를 함께 보인다`() {
        let captures = [
            captureFixture("a.jpg", game: nil),
            captureFixture("b.jpg", game: "기타"),
            captureFixture("c.jpg"),
        ]
        #expect(CaptureQuery(scope: .game("기타"), kind: .all)
            .captures(in: captures, index: LedgerIndex(), serialNumber: "S1", now: .now).map(\.filename)
            == ["a.jpg", "b.jpg"])
    }

    @Test func `필터가 모두일 때 동영상 범위는 동영상을 보인다고 한다`() {
        #expect(CaptureQuery(scope: .videos, kind: .all).shownKind == .videos)
        #expect(CaptureQuery(scope: .new, kind: .all).shownKind == .all)
        #expect(CaptureQuery(scope: .videos, kind: .photos).shownKind == .photos)
    }

    @Suite("빈 까닭")
    struct EmptyReasons {
        let ledger: TransferLedger

        init() throws {
            ledger = try TransferLedger(directory: temporaryFolderFixture())
        }

        @Test func `새 항목이 비면 모두 옮겼다고 한다`() throws {
            let capture = captureFixture("a.jpg")
            try ledger.record([capture], serialNumber: "S1", as: .imported)
            #expect(CaptureQuery(scope: .new, kind: .all)
                .emptyReason(in: [capture], index: ledger.index, serialNumber: "S1", now: .now) == .allTransferred)
        }

        @Test func `새 항목이 비면 필터가 있어도 모두 옮겼다고 한다`() throws {
            let capture = captureFixture("a.mp4", kind: .video)
            try ledger.record([capture], serialNumber: "S1", as: .imported)
            #expect(CaptureQuery(scope: .new, kind: .photos)
                .emptyReason(in: [capture], index: ledger.index, serialNumber: "S1", now: .now) == .allTransferred)
        }

        @Test func `최근 옮긴 항목이 비면 30일 동안 옮긴 것이 없다고 한다`() {
            #expect(CaptureQuery(scope: .recentlyTransferred, kind: .all)
                .emptyReason(in: [captureFixture()], index: LedgerIndex(), serialNumber: "S1", now: .now)
                == .noRecentTransfer)
        }

        @Test func `사진만 보는데 동영상만 있으면 필터가 동영상을 가렸다고 한다`() {
            #expect(CaptureQuery(scope: .game("젤다무쌍 봉인전기"), kind: .photos)
                .emptyReason(
                    in: [captureFixture("a.mp4", kind: .video)],
                    index: LedgerIndex(),
                    serialNumber: "S1",
                    now: .now
                ) == .onlyPhotosShown)
        }

        @Test func `동영상만 보는데 사진만 있으면 필터가 사진을 가렸다고 한다`() {
            #expect(CaptureQuery(scope: .all, kind: .videos)
                .emptyReason(in: [captureFixture("a.jpg")], index: LedgerIndex(), serialNumber: "S1", now: .now)
                == .onlyVideosShown)
        }

        @Test func `앨범이 비면 따로 알릴 까닭이 없다`() {
            #expect(CaptureQuery(scope: .all, kind: .all)
                .emptyReason(in: [], index: LedgerIndex(), serialNumber: "S1", now: .now) == nil)
        }
    }
}
