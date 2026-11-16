import Foundation
import Testing
@testable import PullshotKit

@Suite("TransferLedger 테스트")
struct TransferLedgerTests {
    @Suite("새 항목")
    struct NewCaptures {
        @Test func `기록에 없는 캡처만 새 항목이고 기기와 크기가 다르면 다른 캡처다`() throws {
            let ledger = try TransferLedger(directory: temporaryFolderFixture())
            try ledger.record([captureFixture("a.jpg")], serialNumber: "S1", as: .exported)
            let candidates = [captureFixture("a.jpg"), captureFixture("a.jpg", size: 6), captureFixture("b.jpg")]

            #expect(ledger.index.newCaptures(candidates, serialNumber: "S1").map(\.size) == [6, 5])
            #expect(ledger.index.newCaptures([captureFixture("a.jpg")], serialNumber: "S2").count == 1)
        }
    }

    @Suite("색인")
    struct Index {
        @Test func `최근 옮긴 항목은 기준 시각 뒤에 가져오거나 내보낸 캡처다`() throws {
            let ledger = try TransferLedger(directory: temporaryFolderFixture())
            let (old, recent, found) = (captureFixture("a.jpg"), captureFixture("b.jpg"), captureFixture("c.jpg"))
            try ledger.record([old], serialNumber: "S1", as: .imported, at: dateFixture("2026-10-16 23:59:59"))
            try ledger.record([recent], serialNumber: "S1", as: .exported, at: dateFixture("2026-10-17 00:00:00"))
            try ledger.record([found], serialNumber: "S1", as: .foundInFolder, at: dateFixture("2026-11-10 12:00:00"))

            let since = dateFixture("2026-10-17 00:00:00")
            let recently = ledger.index.recentlyTransferred([old, recent, found], serialNumber: "S1", since: since)
            #expect(recently.map(\.filename) == ["b.jpg"])
        }

        @Test func `꺼내 둔 색인은 뒤에 남긴 기록으로 바뀌지 않는다`() throws {
            let ledger = try TransferLedger(directory: temporaryFolderFixture())
            let before = ledger.index
            try ledger.record([captureFixture("a.jpg")], serialNumber: "S1", as: .imported)

            #expect(!before.isTransferred(captureFixture("a.jpg"), serialNumber: "S1"))
            #expect(ledger.index.isTransferred(captureFixture("a.jpg"), serialNumber: "S1"))
        }
    }

    @Suite("저장")
    struct Storage {
        @Test func `기록한 캡처는 다시 열어도 옮긴 것으로 남는다`() throws {
            let folder = temporaryFolderFixture()
            try TransferLedger(directory: folder).record([captureFixture()], serialNumber: "S1", as: .imported)

            #expect(try TransferLedger(directory: folder).index.isTransferred(captureFixture(), serialNumber: "S1"))
        }

        @Test func `끝 줄이 잘린 기록 파일도 앞 줄을 읽고 이어서 기록한다`() throws {
            let folder = temporaryFolderFixture()
            try TransferLedger(directory: folder).record([captureFixture("a.jpg")], serialNumber: "S1", as: .imported)
            let file = try FileHandle(forWritingTo: folder.appending(path: "transfers.jsonl"))
            try file.seekToEnd()
            try file.write(contentsOf: Data(#"{"key":{"seri"#.utf8))
            try file.close()

            try TransferLedger(directory: folder).record([captureFixture("b.jpg")], serialNumber: "S1", as: .imported)
            let reopened = try TransferLedger(directory: folder)

            #expect(reopened.index.isTransferred(captureFixture("a.jpg"), serialNumber: "S1"))
            #expect(reopened.index.isTransferred(captureFixture("b.jpg"), serialNumber: "S1"))
        }
    }

    @Suite("지난번 옮김")
    struct LastTransfers {
        @Test func `지난번 옮긴 날은 가져오기와 내보내기만 보고 그날 옮긴 수를 센다`() throws {
            let ledger = try TransferLedger(directory: temporaryFolderFixture())
            let (a, b, c) = (captureFixture("a.jpg"), captureFixture("b.jpg"), captureFixture("c.jpg"))
            try ledger.record([a, b], serialNumber: "S1", as: .imported, at: dateFixture("2026-11-08 10:00:00"))
            try ledger.record([a], serialNumber: "S1", as: .exported, at: dateFixture("2026-11-09 21:00:00"))
            try ledger.record([c], serialNumber: "S1", as: .markedAll, at: dateFixture("2026-11-10 09:00:00"))

            #expect(ledger.index.lastTransfer(of: [a, b, c], serialNumber: "S1", calendar: calendarFixture())
                == LastTransfer(day: dateFixture("2026-11-09 00:00:00"), count: 1))
            #expect(ledger.index.transferredAt(a, serialNumber: "S1") == dateFixture("2026-11-09 21:00:00"))
            #expect(ledger.index.transferredAt(c, serialNumber: "S1") == nil)
            #expect(ledger.index.isTransferred(c, serialNumber: "S1"))
        }
    }
}
