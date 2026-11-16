import Foundation
import Testing
@testable import PullshotKit

@Suite("DestinationNamer 테스트")
struct DestinationNamerTests {
    static func emptyFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "namer-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    @Suite("받을 곳 정하기")
    struct Destination {
        @Test func `같은 이름이 없으면 그 이름으로 쓴다`() throws {
            let folder = try emptyFolder()

            #expect(DestinationNamer.decide(filename: "a.jpg", size: 3, in: folder)
                == .write(folder.appending(path: "a.jpg")))
        }

        @Test func `같은 이름과 크기의 파일이 있으면 건너뛴다`() throws {
            let folder = try emptyFolder()
            try Data([1, 2, 3]).write(to: folder.appending(path: "a.jpg"))

            #expect(DestinationNamer.decide(filename: "a.jpg", size: 3, in: folder)
                == .skip(folder.appending(path: "a.jpg")))
        }

        @Test func `이름만 같으면 비어 있는 다음 번호를 붙인다`() throws {
            let folder = try emptyFolder()
            try Data([1]).write(to: folder.appending(path: "a.jpg"))
            try Data([1]).write(to: folder.appending(path: "a 2.jpg"))

            #expect(DestinationNamer.decide(filename: "a.jpg", size: 3, in: folder)
                == .write(folder.appending(path: "a 3.jpg")))
        }

        @Test func `번호 붙은 사본이 같은 크기로 이미 있으면 다시 받지 않는다`() throws {
            let folder = try emptyFolder()
            try Data([1]).write(to: folder.appending(path: "a.jpg"))
            try Data([1, 2, 3]).write(to: folder.appending(path: "a 2.jpg"))

            #expect(DestinationNamer.decide(filename: "a.jpg", size: 3, in: folder)
                == .skip(folder.appending(path: "a 2.jpg")))
        }

        @Test func `크기를 모르면 같은 이름이 있을 때 번호를 붙인다`() throws {
            let folder = try emptyFolder()
            try Data([1]).write(to: folder.appending(path: "a.jpg"))

            #expect(DestinationNamer.decide(filename: "a.jpg", size: nil, in: folder)
                == .write(folder.appending(path: "a 2.jpg")))
        }
    }
}
