import Foundation
import Testing
@testable import PullshotApp

@Suite("DeviceWorker 테스트")
struct DeviceWorkerTests {
    @Suite("받아 둔 미리보기 원본")
    struct PreviewOriginal {
        /// 받아 둔 파일의 바이트 수(nil이면 파일 없음), 캡처의 크기(nil이면 모름), 다시 받지 않는지입니다.
        @Test(arguments: [
            (5, 5, true),
            (3, 5, false),
            (nil, 5, false),
            (5, nil, false),
        ] as [(Int?, UInt64?, Bool)])
        func `크기를 아는 캡처와 크기가 같은 파일이 있을 때만 다시 받지 않는다`(
            fileBytes: Int?,
            captureSize: UInt64?,
            hasPreview: Bool
        ) throws {
            let folder = temporaryFolderFixture()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let file = folder.appending(path: "2026111421120500_s.jpg")
            if let fileBytes {
                try Data(count: fileBytes).write(to: file)
            }
            #expect(DeviceWorker.hasPreview(of: captureFixture(size: captureSize), at: file) == hasPreview)
        }
    }
}
