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

    @Test func `게임 범위에 동영상 필터를 더하면 그 게임의 동영상만 보인다`() {
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

    @Test func `보일 캡처는 날짜 보기에 놓이는 칸 순서와 같다`() {
        let captures = [
            captureFixture("a.jpg", at: "2026-10-31 23:00:00"),
            captureFixture("b.jpg", at: nil),
            captureFixture("c.jpg", at: "2026-11-01 09:00:00"),
            captureFixture("e.jpg", at: "2026-11-01 08:00:00"),
            captureFixture("d.jpg", at: "2026-11-01 08:00:00"),
        ]
        let shown = CaptureQuery(scope: .all, kind: .all)
            .captures(in: captures, index: LedgerIndex(), serialNumber: "S1", now: .now)
        let sections = DateSections(captures, calendar: calendarFixture())
        let screen = sections.months.flatMap { $0.days.flatMap(\.captures) } + sections.undated
        #expect(shown.map(\.filename) == ["c.jpg", "d.jpg", "e.jpg", "a.jpg", "b.jpg"])
        #expect(screen.map(\.filename) == shown.map(\.filename))
    }

    @Suite("빈 까닭")
    struct EmptyReasons {
        @Test func `새 항목이 비면 필터가 있어도 모두 옮겼다고 한다`() throws {
            let ledger = try TransferLedger(directory: temporaryFolderFixture())
            let capture = captureFixture("a.mp4", kind: .video)
            try ledger.record([capture], serialNumber: "S1", as: .imported)
            #expect(CaptureQuery(scope: .new, kind: .photos)
                .emptyReason(in: [capture], index: ledger.index, serialNumber: "S1", now: .now) == .allTransferred)
        }

        @Test(arguments: [
            (KindFilter.photos, captureFixture("a.mp4", kind: .video), EmptyReason.onlyPhotosShown),
            (.videos, captureFixture("a.jpg"), .onlyVideosShown),
        ] as [(KindFilter, Capture, EmptyReason)])
        func `보는 종류의 캡처가 없으면 필터가 다른 종류를 가렸다고 한다`(
            kind: KindFilter,
            capture: Capture,
            reason: EmptyReason
        ) {
            #expect(CaptureQuery(scope: .all, kind: kind)
                .emptyReason(in: [capture], index: LedgerIndex(), serialNumber: "S1", now: .now) == reason)
        }
    }
}
