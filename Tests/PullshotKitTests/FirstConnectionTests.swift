import Foundation
import Testing
@testable import PullshotKit

@Suite("처음 연결 테스트")
struct FirstConnectionTests {
    @Suite("물을지")
    struct Asking {
        @Test func `기록도 답도 없는 기기에만 묻고 한 번 답하면 다시 묻지 않는다`() throws {
            let folder = temporaryFolderFixture()
            let ledger = try TransferLedger(directory: folder)
            #expect(ledger.shouldAskFirstConnectQuestion(serialNumber: "S1"))

            let recorded = try ledger.answerFirstConnectQuestion(
                .leaveAllNew,
                captures: [captureFixture()],
                serialNumber: "S1"
            )

            #expect(recorded == 0)

            #expect(try !TransferLedger(directory: folder).shouldAskFirstConnectQuestion(serialNumber: "S1"))
            #expect(ledger.index.newCaptures([captureFixture()], serialNumber: "S1").count == 1)
        }

        @Test func `기록이 이미 있는 기기는 묻지 않는다`() throws {
            let ledger = try TransferLedger(directory: temporaryFolderFixture())
            try ledger.record([captureFixture()], serialNumber: "S1", as: .imported)

            #expect(!ledger.shouldAskFirstConnectQuestion(serialNumber: "S1"))
        }

        @Test func `답한 기기 파일이 깨져도 기록을 열고 다시 묻는다`() throws {
            let folder = temporaryFolderFixture()
            try TransferLedger(directory: folder).record([captureFixture("a.jpg")], serialNumber: "S1", as: .imported)
            try Data(#"["S2""#.utf8).write(to: folder.appending(path: "answered-devices.json"))
            let ledger = try TransferLedger(directory: folder)

            #expect(ledger.index.isTransferred(captureFixture("a.jpg"), serialNumber: "S1"))
            #expect(ledger.shouldAskFirstConnectQuestion(serialNumber: "S2"))

            _ = try ledger.answerFirstConnectQuestion(.leaveAllNew, captures: [], serialNumber: "S2")

            #expect(try !TransferLedger(directory: folder).shouldAskFirstConnectQuestion(serialNumber: "S2"))
        }
    }

    @Suite("답")
    struct Answering {
        @Test func `모두 가져온 것으로 표시하면 지금 캡처를 모두 기록한다`() throws {
            let ledger = try TransferLedger(directory: temporaryFolderFixture())
            let captures = [captureFixture("a.jpg"), captureFixture("b.jpg")]

            #expect(try ledger.answerFirstConnectQuestion(.markAll, captures: captures, serialNumber: "S1") == 2)
            #expect(ledger.index.newCaptures(captures, serialNumber: "S1").isEmpty)
        }

        @Test func `찾기를 취소하면 아무것도 기록하지 않고 다시 묻는다`() throws {
            let root = temporaryFolderFixture()
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try Data(count: 5).write(to: root.appending(path: "2026111421120500_s.jpg"))
            let ledger = try TransferLedger(directory: temporaryFolderFixture())

            #expect(throws: CancellationError.self) {
                try ledger.answerFirstConnectQuestion(
                    .findInFolder(root),
                    captures: [captureFixture()],
                    serialNumber: "S1",
                    isCancelled: { true }
                )
            }
            #expect(ledger.shouldAskFirstConnectQuestion(serialNumber: "S1"))
        }
    }

    @Suite("폴더에서 찾기")
    struct FindingInFolder {
        @Test func `폴더 어디에 있든 이름과 크기가 같은 캡처만 가져온 것으로 기록한다`() throws {
            let root = temporaryFolderFixture()
            let nested = root.appending(path: "2025/젤다")
            try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
            try Data(count: 5).write(to: nested.appending(path: "a.jpg"))
            try Data(count: 9).write(to: root.appending(path: "b.jpg"))
            let ledger = try TransferLedger(directory: temporaryFolderFixture())
            let captures = [captureFixture("a.jpg"), captureFixture("b.jpg"), captureFixture("c.jpg")]

            let recorded = try ledger.answerFirstConnectQuestion(
                .findInFolder(root),
                captures: captures,
                serialNumber: "S1"
            )

            #expect(recorded == 1)
            #expect(ledger.index.newCaptures(captures, serialNumber: "S1").map(\.filename) == ["b.jpg", "c.jpg"])
        }

        @Test func `없거나 읽을 수 없는 폴더를 주면 기록하지 않고 다시 묻는다`() throws {
            let missing = temporaryFolderFixture()
            let ledger = try TransferLedger(directory: temporaryFolderFixture())

            #expect(throws: FolderMatchError.unreadableFolder(missing)) {
                try ledger.answerFirstConnectQuestion(
                    .findInFolder(missing),
                    captures: [captureFixture()],
                    serialNumber: "S1"
                )
            }
            #expect(ledger.shouldAskFirstConnectQuestion(serialNumber: "S1"))
        }

        @Test func `읽을 수 없는 하위 폴더가 있어도 나머지에서 찾는다`() throws {
            let root = temporaryFolderFixture()
            let locked = root.appending(path: "locked")
            try FileManager.default.createDirectory(at: locked, withIntermediateDirectories: true)
            try Data(count: 5).write(to: locked.appending(path: "x.jpg"))
            try Data(count: 5).write(to: root.appending(path: "a.jpg"))
            let lockedPath = locked.path(percentEncoded: false)
            try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: lockedPath)
            defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: lockedPath) }

            #expect(try FolderMatcher.captures([captureFixture("a.jpg")], foundUnder: root).count == 1)
        }
    }
}
