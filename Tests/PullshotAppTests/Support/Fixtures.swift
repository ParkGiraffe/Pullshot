import Foundation
@testable import PullshotApp
@testable import PullshotKit

enum StringsTableError: Error {
    case unreadable(String)
}

private let repositoryFolder = URL(filePath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
private let appFolder = repositoryFolder.appending(path: "App")

func stringsTable(_ language: String) throws -> [String: String] {
    let data = try Data(contentsOf: appFolder.appending(path: "\(language).lproj/Localizable.strings"))
    guard let table = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String],
          !table.isEmpty
    else { throw StringsTableError.unreadable(language) }
    return table
}

func dateFixture(_ text: String) -> Date {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    guard let date = formatter.date(from: text) else { preconditionFailure("날짜 형식이 다릅니다: \(text)") }
    return date
}

func calendarFixture() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .gmt
    return calendar
}

func captureFixture(
    _ filename: String = "2026111421120500_s.jpg",
    game: String? = "젤다무쌍 봉인전기",
    at capturedAt: String? = "2026-11-14 21:12:05",
    size: UInt64? = 5,
    kind: Capture.Kind = .photo
) -> Capture {
    Capture(
        handle: 1,
        storageID: 0x0001_0001,
        filename: filename,
        size: size,
        capturedAt: capturedAt.map(dateFixture),
        kind: kind,
        gameFolder: game
    )
}

private let temporaryRoot: URL = {
    let root = FileManager.default.temporaryDirectory.appending(path: "PullshotTests/App")
    try? FileManager.default.removeItem(at: root)
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}()

func temporaryFolderFixture() -> URL {
    temporaryRoot.appending(path: "\(UUID())")
}

func defaultsFixture() -> UserDefaults {
    guard let defaults = TemporaryDefaults(suitePath: temporaryFolderFixture().path(percentEncoded: false)) else {
        preconditionFailure("설정 저장소를 만들지 못했습니다")
    }
    return defaults
}

private final class TemporaryDefaults: UserDefaults {
    private let suitePath: String

    init?(suitePath: String) {
        self.suitePath = suitePath
        super.init(suiteName: suitePath)
    }

    deinit {
        removePersistentDomain(forName: suitePath)
        try? FileManager.default.removeItem(atPath: "\(suitePath).plist")
    }
}

@MainActor
func libraryModelFixture() throws -> LibraryModel {
    let worker = try DeviceWorker(
        ledgerDirectory: temporaryFolderFixture(),
        log: FileLog(file: temporaryFolderFixture().appending(path: "pullshot.log"))
    )
    return LibraryModel(worker: worker, settings: AppSettings(defaults: defaultsFixture()))
}

func consoleFixture(_ registryID: UInt64, model: ConsoleModel = .switch2) -> AttachedConsole {
    AttachedConsole(model: model, registryID: registryID, locationID: nil, serialNumber: "XKJ1000\(registryID)")
}
