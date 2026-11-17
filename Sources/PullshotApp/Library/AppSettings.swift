import Foundation
import Observation
import PullshotKit

@MainActor @Observable
final class AppSettings {
    var importFolder: URL {
        didSet { defaults.set(importFolder.path(percentEncoded: false), forKey: SettingsKey.importFolder.rawValue) }
    }

    var makesGameFolder: Bool {
        didSet { defaults.set(makesGameFolder, forKey: SettingsKey.makesGameFolder.rawValue) }
    }

    var exportNaming: ExportNaming {
        didSet { defaults.set(exportNaming.rawValue, forKey: SettingsKey.exportNaming.rawValue) }
    }

    var isVerboseLog: Bool {
        didSet { defaults.set(isVerboseLog, forKey: SettingsKey.isVerboseLog.rawValue) }
    }

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
