import Foundation
@testable import PullshotKit

/// 앱 뿌리의 `App/<언어>.lproj/Localizable.strings`를 읽습니다. 테스트 파일 위치에서 리포 뿌리를 찾습니다.
func stringsTable(_ language: String) throws -> [String: String] {
    let repositoryRoot = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let data = try Data(contentsOf: repositoryRoot.appending(path: "App/\(language).lproj/Localizable.strings"))
    let table = try PropertyListSerialization.propertyList(from: data, format: nil)
    return table as? [String: String] ?? [:]
}

/// "yyyy-MM-dd HH:mm:ss"를 서울 시각으로 읽습니다.
func dateFixture(_ text: String) -> Date {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    guard let date = formatter.date(from: text) else { preconditionFailure("날짜 형식이 다릅니다: \(text)") }
    return date
}

/// 훑기를 거친 캡처입니다. 찍은 시각은 서울 시각 글로 받습니다.
func captureFixture(
    _ filename: String = "2026111421120500_s.jpg",
    game: String? = "젤다무쌍 봉인전기",
    at capturedAt: String? = "2026-11-14 21:12:05",
    size: UInt64? = 5,
    kind: Capture.Kind = .photo,
    handle: UInt32 = 1
) -> Capture {
    Capture(
        handle: handle,
        storageID: 0x0001_0001,
        filename: filename,
        size: size,
        capturedAt: capturedAt.map(dateFixture),
        kind: kind,
        gameFolder: game
    )
}

/// 임시 폴더 아래 새 경로입니다. 만들지는 않습니다.
func temporaryFolderFixture() -> URL {
    FileManager.default.temporaryDirectory.appending(path: "pullshot-\(UUID())")
}
