import Foundation
import Testing
@testable import PullshotKit

@Suite("Transfer 테스트")
struct TransferTests {
    /// 받을 곳, 기록, 가짜 기기입니다.
    struct Setup {
        let root = temporaryFolderFixture()
        let ledger: TransferLedger
        let source = FakeDownloadSource()

        init() throws {
            ledger = try TransferLedger(directory: temporaryFolderFixture())
        }

        var transfer: Transfer {
            Transfer(source: source, ledger: ledger, serialNumber: "S1")
        }

        func run(_ captures: [Capture], isCancelled: () -> Bool = { false }) throws -> TransferSummary {
            try transfer.run(TransferItem.imports(captures, into: root), as: .imported, isCancelled: isCancelled)
        }

        /// 받을 곳의 게임 폴더에 파일을 미리 둡니다.
        func place(_ data: Data, named filename: String) throws -> URL {
            let folder = root.appending(path: "젤다무쌍 봉인전기")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let file = folder.appending(path: filename)
            try data.write(to: file)
            return file
        }
    }

    static let three = (1 ... 3).map { captureFixture("\($0).jpg", handle: UInt32($0)) }

    @Suite("받기")
    struct Receiving {
        @Test func `받은 파일은 기록에 남고 만든 날짜와 수정 날짜가 찍은 시각이다`() throws {
            let setup = try Setup()
            let capture = captureFixture("a.jpg")
            let summary = try setup.run([capture])

            let saved = try #require(summary.saved.first).path(percentEncoded: false)
            let attributes = try FileManager.default.attributesOfItem(atPath: saved)
            #expect(attributes[.creationDate] as? Date == capture.capturedAt)
            #expect(attributes[.modificationDate] as? Date == capture.capturedAt)
            #expect(setup.ledger.index.isTransferred(capture, serialNumber: "S1"))
        }

        @Test func `진행은 캡처를 시작할 때와 바이트를 받을 때 알린다`() throws {
            let setup = try Setup()
            var reported: [TransferProgress] = []
            _ = try setup.transfer.run(
                TransferItem.imports(Array(three.prefix(2)), into: setup.root),
                as: .imported,
                progress: { reported.append($0) }
            )

            #expect(reported.map(\.index) == [0, 0, 1, 1])
            #expect(reported.map(\.total) == [2, 2, 2, 2])
            #expect(reported.map(\.bytes) == [0, 5, 0, 5])
        }

        @Test func `한 캡처가 실패해도 나머지를 받는다`() throws {
            let setup = try Setup()
            setup.source.outcomes[2] = .fail(SessionError.response(.generalError, operation: .getObject))
            let summary = try setup.run(three)

            #expect(summary.saved.count == 2)
            #expect(summary.failures.map(\.capture.handle) == [2])
            #expect(summary.notAttempted == 0)
        }
    }

    @Suite("이미 있는 파일")
    struct ExistingFiles {
        @Test func `같은 이름과 크기의 파일이 있으면 받지 않고 기록만 남긴다`() throws {
            let setup = try Setup()
            let capture = captureFixture("a.jpg")
            _ = try setup.place(Data(count: 5), named: "a.jpg")
            let summary = try setup.run([capture])

            #expect(setup.source.downloaded.isEmpty)
            #expect(summary.skipped == 1)
            #expect(setup.ledger.index.isTransferred(capture, serialNumber: "S1"))
        }

        @Test func `이름만 같은 파일이 있으면 번호를 붙여 따로 받고 원래 파일은 그대로 둔다`() throws {
            let setup = try Setup()
            let original = try setup.place(Data(repeating: 1, count: 3), named: "a.jpg")
            let summary = try setup.run([captureFixture("a.jpg")])

            #expect(summary.saved.map(\.lastPathComponent) == ["a 2.jpg"])
            #expect(try Data(contentsOf: original) == Data(repeating: 1, count: 3))
        }
    }

    @Suite("이미 옮긴 캡처")
    struct AlreadyTransferred {
        @Test func `이미 있던 파일을 건너뛰면 지난번 옮긴 날을 바꾸지 않는다`() throws {
            let setup = try Setup()
            let (a, b) = (captureFixture("a.jpg"), captureFixture("b.jpg"))
            _ = try setup.run([a])
            let firstTransfer = setup.ledger.index.transferredAt(a, serialNumber: "S1")
            _ = try setup.place(Data(count: 5), named: "b.jpg")

            _ = try setup.run([a, b])

            #expect(setup.ledger.index.transferredAt(a, serialNumber: "S1") == firstTransfer)
            #expect(setup.ledger.index.isTransferred(b, serialNumber: "S1"))
            #expect(setup.ledger.index.transferredAt(b, serialNumber: "S1") == nil)
        }
    }

    @Suite("멈춤")
    struct Stopping {
        @Test func `연결이 끊기면 멈추고 시도하지 못한 수를 센다`() throws {
            let setup = try Setup()
            setup.source.outcomes[2] = .disconnect
            let summary = try setup.run(three)

            #expect(summary.saved.count == 1)
            #expect(summary.failures.map(\.capture.handle) == [2])
            #expect(summary.notAttempted == 1)
            #expect(setup.source.downloaded == [1, 2])
            #expect(setup.ledger.index.newCaptures(three, serialNumber: "S1").map(\.handle) == [2, 3])
        }

        @Test func `받는 중에 취소하면 남은 캡처를 받지 않고 받은 것만 기록한다`() throws {
            let setup = try Setup()
            setup.source.outcomes[2] = .cancel
            let summary = try setup.run(three)

            #expect(summary.isCancelled)
            #expect(summary.saved.count == 1)
            #expect(summary.failures.isEmpty)
            #expect(summary.notAttempted == 2)
            #expect(setup.ledger.index.newCaptures(three, serialNumber: "S1").map(\.handle) == [2, 3])
        }

        @Test func `캡처 사이에서 취소를 알아채면 다음 캡처를 시작하지 않는다`() throws {
            let setup = try Setup()
            let summary = try setup.run(three, isCancelled: { setup.source.downloaded.count == 1 })

            #expect(setup.source.downloaded == [1])
            #expect(summary.isCancelled)
            #expect(summary.notAttempted == 2)
        }
    }
}
