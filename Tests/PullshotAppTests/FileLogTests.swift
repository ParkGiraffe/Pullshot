import Foundation
import PullshotKit
import Testing
@testable import PullshotApp

@Suite("FileLog 테스트")
struct FileLogTests {
    @Suite("오류 적기")
    struct Describing {
        @Test func `파일 이름이 든 오류도 로그에는 이름을 남기지 않는다`() {
            #expect(FileLog.describe(SessionError.destinationExists("젤다.jpg")) == "destinationExists")
            #expect(FileLog.describe(FolderMatchError.unreadableFolder(URL(filePath: "/Users/a/사진")))
                == "unreadableFolder")
            let permissionError = CocoaError(.fileWriteNoPermission, userInfo: [NSFilePathErrorKey: "/Users/a/b.jpg"])
            #expect(FileLog.describe(permissionError) == "NSCocoaErrorDomain 513")
        }

        @Test func `기기 오류는 종류와 코드를 남긴다`() {
            #expect(FileLog.describe(SessionError.transport(.disconnected)) == "transport(disconnected)")
            #expect(FileLog.describe(SessionError.response(PTP.Response(rawValue: 0x2002), operation: .getObject))
                == "response(0x2002, 0x1009)")
            #expect(FileLog.describe(ConsoleAccessError.heldByAnotherApp(code: 0xE000_02C9, owner: "ptpcamerad"))
                == "heldByAnotherApp(0xE00002C9, ptpcamerad)")
        }
    }

    @Suite("파일 크기")
    struct Rotation {
        @Test func `열 때 5MB를 넘은 로그는 앞 파일로 옮기고 새로 쓴다`() throws {
            let folder = temporaryFolderFixture()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let file = folder.appending(path: "pullshot.log")
            try Data(count: 5_000_001).write(to: file)

            FileLog(file: file).write("열림")

            #expect(try Data(contentsOf: folder.appending(path: "pullshot.1.log")).count == 5_000_001)
            #expect(try String(contentsOf: file, encoding: .utf8).hasSuffix(" 열림\n"))
        }
    }
}
