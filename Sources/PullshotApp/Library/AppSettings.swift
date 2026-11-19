import Foundation
import Observation
import PullshotKit

@MainActor @Observable
final class AppSettings {
    var importFolder: URL {
        didSet { defaults.set(importFolder.path(percentEncoded: false), forKey: SettingsKey.importFolder.rawValue) }
    }

    var shouldMakeGameFolder: Bool {
        didSet { defaults.set(shouldMakeGameFolder, forKey: SettingsKey.shouldMakeGameFolder.rawValue) }
    }

    var importNaming: ExportNaming {
        didSet { defaults.set(importNaming.rawValue, forKey: SettingsKey.importNaming.rawValue) }
    }

    var isVerboseLogging: Bool {
        didSet { defaults.set(isVerboseLogging, forKey: SettingsKey.isVerboseLogging.rawValue) }
    }

    var appIcon: AppIcon {
        didSet { defaults.set(appIcon.rawValue, forKey: SettingsKey.appIcon.rawValue) }
    }

    var shouldCheckForUpdates: Bool {
        didSet { defaults.set(shouldCheckForUpdates, forKey: SettingsKey.shouldCheckForUpdates.rawValue) }
    }

    var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: SettingsKey.language.rawValue)
            if let languages = language.preferredLanguages {
                defaults.set(languages, forKey: SettingsKey.appleLanguages.rawValue)
            } else {
                defaults.removeObject(forKey: SettingsKey.appleLanguages.rawValue)
            }
        }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        importFolder = defaults.string(forKey: SettingsKey.importFolder.rawValue).map { URL(filePath: $0) }
            ?? TransferItem.defaultImportFolder
        shouldMakeGameFolder = defaults.object(forKey: SettingsKey.shouldMakeGameFolder.rawValue) == nil
            || defaults.bool(forKey: SettingsKey.shouldMakeGameFolder.rawValue)
        importNaming = defaults.string(forKey: SettingsKey.importNaming.rawValue)
            .flatMap(ExportNaming.init) ?? .original
        isVerboseLogging = defaults.bool(forKey: SettingsKey.isVerboseLogging.rawValue)
        appIcon = defaults.string(forKey: SettingsKey.appIcon.rawValue).flatMap(AppIcon.init) ?? .red
        shouldCheckForUpdates = defaults.bool(forKey: SettingsKey.shouldCheckForUpdates.rawValue)
        language = defaults.string(forKey: SettingsKey.language.rawValue).flatMap(AppLanguage.init) ?? .system
    }
}
