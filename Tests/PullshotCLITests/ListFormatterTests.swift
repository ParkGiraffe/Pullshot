import Foundation
import PullshotKit
import Testing
@testable import pullshot

@Suite("ListFormatter 테스트")
struct ListFormatterTests {
    @Suite("목록 쓰기")
    struct Listing {
        @Test func `게임을 최근 캡처 순으로 묶고 게임 밖의 캡처는 기타로 끝에 둔다`() {
            let scan = AlbumScan(captures: [
                captureFixture("20261101090000_1.jpg", game: nil, at: "20261120T090000", size: 400_000),
                captureFixture("20261114211205_1.jpg", at: "20261114T211205", size: 1_100_000),
                captureFixture("20261114211800_1.mp4", at: "20261114T211800", size: 31_200_000, kind: .video),
            ], skipped: [])

            #expect(ListFormatter.lines(scan, timeZone: timeZoneFixture()) == [
                "젤다무쌍 봉인전기 (2)",
                "  20261114211800_1.mp4  영상  31.2 MB  2026-11-14 21:18",
                "  20261114211205_1.jpg  사진   1.1 MB  2026-11-14 21:12",
                "기타 (1)",
                "  20261101090000_1.jpg  사진   0.4 MB  2026-11-20 09:00",
            ])
        }

        @Test func `새 항목에는 줄 끝에 새 항목이라고 표시한다`() {
            let capture = captureFixture("2026111421120500_s.jpg", at: "20261114T211205")
            let scan = AlbumScan(captures: [capture], skipped: [])

            #expect(ListFormatter.lines(scan, isNew: { _ in true }, timeZone: timeZoneFixture()) == [
                "젤다무쌍 봉인전기 (1)",
                "  2026111421120500_s.jpg  사진  0.0 MB  2026-11-14 21:12  새 항목",
            ])
        }
    }
}
