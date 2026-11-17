import Foundation
import Observation
import PullshotKit

/// 오른쪽 칸, 설정 창, 옮기기가 함께 쓰는 설정입니다. 이 설정들의 기본값과 `UserDefaults`를 읽는 법을 여기 둡니다.
/// 앱을 열 때 한 번만 읽는 기록 폴더(`AppDelegate`)와 데모 여부(`LibraryModel`), 화면만 쓰는 썸네일 크기와
/// 보기 방식(`LibraryWindow`의 `@AppStorage`)은 쓰는 곳에서 읽습니다.
/// 실행 인자(`-makesGameFolder NO`)는 문자열로 들어오므로 참거짓은 `bool(forKey:)`로 읽습니다.
@MainActor @Observable
final class AppSettings {
    /// 저장 위치입니다. 가져오기는 모두 이 폴더 아래에 둡니다. 앞 버전의 가져올 곳 설정을 이어 쓰려고 키는 그대로 둡니다.
    var importFolder: URL {
        didSet { defaults.set(importFolder.path(percentEncoded: false), forKey: SettingsKey.importFolder.rawValue) }
    }

    /// 고른 것을 가져올 때 저장 위치 아래에 게임 이름 폴더를 만들어 나눠 둡니다("폴더별로 나눠 저장").
    var makesGameFolder: Bool {
        didSet { defaults.set(makesGameFolder, forKey: SettingsKey.makesGameFolder.rawValue) }
    }

    /// 고른 것을 가져올 때의 파일 이름 규칙입니다. 이름은 Kit의 `ExportNaming`을 따르고, 키는 앞 버전 설정을 이어 쓰려고
    /// 그대로 둡니다.
    var exportNaming: ExportNaming {
        didSet { defaults.set(exportNaming.rawValue, forKey: SettingsKey.exportNaming.rawValue) }
    }

    /// 스위치와 주고받은 내용을 파일 로그에 남깁니다. 다음 연결부터 씁니다.
    var isVerboseLog: Bool {
        didSet { defaults.set(isVerboseLog, forKey: SettingsKey.isVerboseLog.rawValue) }
    }

    /// Dock에 보일 앱 아이콘입니다. 앱을 열 때(`AppDelegate`)와 설정 창에서 고를 때 Dock에 반영합니다.
    var appIcon: AppIcon {
        didSet { defaults.set(appIcon.rawValue, forKey: SettingsKey.appIcon.rawValue) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        importFolder = defaults.string(forKey: SettingsKey.importFolder.rawValue).map { URL(filePath: $0) }
            ?? TransferItem.defaultImportFolder
        makesGameFolder = defaults.object(forKey: SettingsKey.makesGameFolder.rawValue) == nil
            || defaults.bool(forKey: SettingsKey.makesGameFolder.rawValue)
        exportNaming = defaults.string(forKey: SettingsKey.exportNaming.rawValue)
            .flatMap(ExportNaming.init) ?? .original
        isVerboseLog = defaults.bool(forKey: SettingsKey.isVerboseLog.rawValue)
        appIcon = defaults.string(forKey: SettingsKey.appIcon.rawValue).flatMap(AppIcon.init) ?? .red
    }
}
