import Foundation
@testable import PullshotApp
@testable import PullshotKit

/// 문자열 표가 사전이 아니거나 비어 있을 때 던집니다. 빈 표끼리 비교해 테스트가 통과하는 일을 막습니다.
enum StringsTableError: Error {
    case unreadable(String)
}

/// 리포 뿌리입니다. 테스트 파일 위치에서 찾습니다.
private let repositoryFolder = URL(filePath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
private let appFolder = repositoryFolder.appending(path: "App")
/// 앱 아이콘 그림이 있는 폴더입니다. `make app`이 여기 그림으로 `.icns`를 만듭니다.
let appIconDesignFolder = repositoryFolder.appending(path: "design/app-icon")

func stringsTable(_ language: String, table: String = "Localizable") throws -> [String: String] {
    let data = try Data(contentsOf: appFolder.appending(path: "\(language).lproj/\(table).strings"))
    guard let table = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String],
          !table.isEmpty
    else { throw StringsTableError.unreadable(language) }
    return table
}

/// `App/Info.plist`를 읽습니다. 개발 언어인 한국어 값이 여기 있습니다.
func infoPlist() throws -> [String: Any] {
    let data = try Data(contentsOf: appFolder.appending(path: "Info.plist"))
    guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
        throw StringsTableError.unreadable("Info.plist")
    }
    return plist
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

/// 그레고리력, 서울 시간대입니다. 날짜 묶기가 실행하는 곳의 시간대에 기대지 않게 합니다.
func calendarFixture() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .gmt
    return calendar
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

/// 테스트마다 따로 쓰는 설정 저장소입니다. suite 이름에 절대 경로를 주면 `~/Library/Preferences`가 아니라
/// 그 경로의 plist에 써서, 테스트가 사용자 설정 폴더에 파일을 남기지 않습니다(2026-11-16, macOS 27.2 확인).
func defaultsFixture() -> UserDefaults {
    guard let defaults = UserDefaults(suiteName: temporaryFolderFixture().path(percentEncoded: false)) else {
        preconditionFailure("설정 저장소를 만들지 못했습니다")
    }
    return defaults
}

/// 기기를 열지 않은 모델입니다. 옮긴 기록, 로그, 설정은 테스트마다 따로 둡니다.
@MainActor
func libraryModelFixture() throws -> LibraryModel {
    let worker = try DeviceWorker(
        ledgerDirectory: temporaryFolderFixture(),
        log: FileLog(file: temporaryFolderFixture().appending(path: "pullshot.log"))
    )
    return LibraryModel(worker: worker, settings: AppSettings(defaults: defaultsFixture()))
}

/// PC로 복사 모드로 꽂힌 스위치입니다. 같은 기기인지는 `registryID`로 가립니다.
func consoleFixture(_ registryID: UInt64, model: ConsoleModel = .switch2) -> AttachedConsole {
    AttachedConsole(model: model, registryID: registryID, locationID: nil, serialNumber: "XKJ1000\(registryID)")
}
