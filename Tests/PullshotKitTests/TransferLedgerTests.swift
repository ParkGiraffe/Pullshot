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

            #expect(ledger.newCaptures(candidates, serialNumber: "S1").map(\.size) == [6, 5])
            #expect(ledger.newCaptures([captureFixture("a.jpg")], serialNumber: "S2").count == 1)
        }
    }

    @Suite("저장")
    struct Storage {
        @Test func `기록한 캡처는 다시 열어도 옮긴 것으로 남는다`() throws {
            let folder = temporaryFolderFixture()
            try TransferLedger(directory: folder).record([captureFixture()], serialNumber: "S1", as: .imported)

            #expect(try TransferLedger(directory: folder).isTransferred(captureFixture(), serialNumber: "S1"))
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

            #expect(reopened.isTransferred(captureFixture("a.jpg"), serialNumber: "S1"))
            #expect(reopened.isTransferred(captureFixture("b.jpg"), serialNumber: "S1"))
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
            var seoul = Calendar(identifier: .gregorian)
            seoul.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .gmt

            #expect(ledger.lastTransfer(of: [a, b, c], serialNumber: "S1", calendar: seoul)
                == LastTransfer(day: dateFixture("2026-11-09 00:00:00"), count: 1))
            #expect(ledger.transferredAt(a, serialNumber: "S1") == dateFixture("2026-11-09 21:00:00"))
            #expect(ledger.transferredAt(c, serialNumber: "S1") == nil)
            #expect(ledger.isTransferred(c, serialNumber: "S1"))
        }
    }
}
