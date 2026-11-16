import Foundation
import Observation
import PullshotKit

/// 오른쪽 칸, 설정 창, 옮기기가 함께 쓰는 설정입니다. 기본값과 `UserDefaults`를 읽는 법을 여기 한 곳에 둡니다.
/// 실행 인자(`-makesGameFolder NO`)는 문자열로 들어오므로 참거짓은 `bool(forKey:)`로 읽습니다.
@MainActor @Observable
final class AppSettings {
    var importFolder: URL {
        didSet { defaults.set(importFolder.path(percentEncoded: false), forKey: SettingsKey.importFolder.rawValue) }
    }

    /// 내보낼 기준 폴더입니다. 기본값이 없어 처음 내보낼 때 고르기 전까지 nil입니다.
    var exportFolder: URL? {
        didSet { defaults.set(exportFolder?.path(percentEncoded: false), forKey: SettingsKey.exportFolder.rawValue) }
    }

    var makesGameFolder: Bool {
        didSet { defaults.set(makesGameFolder, forKey: SettingsKey.makesGameFolder.rawValue) }
    }

    var exportNaming: ExportNaming {
        didSet { defaults.set(exportNaming.rawValue, forKey: SettingsKey.exportNaming.rawValue) }
    }

    /// 스위치와 주고받은 내용을 파일 로그에 남깁니다. 다음 연결부터 씁니다.
    var isVerboseLog: Bool {
        didSet { defaults.set(isVerboseLog, forKey: SettingsKey.isVerboseLog.rawValue) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        func folder(_ key: SettingsKey) -> URL? {
            defaults.string(forKey: key.rawValue).map { URL(filePath: $0) }
        }
        self.defaults = defaults
        importFolder = folder(.importFolder) ?? TransferItem.defaultImportFolder
        exportFolder = folder(.exportFolder)
        makesGameFolder = defaults.object(forKey: SettingsKey.makesGameFolder.rawValue) == nil
            || defaults.bool(forKey: SettingsKey.makesGameFolder.rawValue)
        exportNaming = defaults.string(forKey: SettingsKey.exportNaming.rawValue)
            .flatMap(ExportNaming.init) ?? .original
        isVerboseLog = defaults.bool(forKey: SettingsKey.isVerboseLog.rawValue)
    }
}
