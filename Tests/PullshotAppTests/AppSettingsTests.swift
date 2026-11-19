import Foundation
import PullshotKit
import Testing
@testable import PullshotApp

@Suite("AppSettings 테스트")
@MainActor
struct AppSettingsTests {
    let defaults = defaultsFixture()

    @Test func `바꾼 설정은 다시 읽어도 남는다`() {
        let settings = AppSettings(defaults: defaults)
        settings.importFolder = URL(filePath: "/tmp/스위치")
        settings.shouldMakeGameFolder = false
        settings.importNaming = .numbered
        settings.isVerboseLogging = true
        settings.appIcon = .shutter
        settings.shouldCheckForUpdates = true
        settings.language = .korean

        let reread = AppSettings(defaults: defaults)
        #expect(reread.importFolder == URL(filePath: "/tmp/스위치"))
        #expect(reread.shouldMakeGameFolder == false)
        #expect(reread.importNaming == .numbered)
        #expect(reread.isVerboseLogging)
        #expect(reread.appIcon == .shutter)
        #expect(reread.shouldCheckForUpdates)
        #expect(reread.language == .korean)
        #expect(defaults.stringArray(forKey: SettingsKey.appleLanguages.rawValue) == ["ko"])
    }

    @Test func `업데이트 자동 확인은 처음에 꺼져 있다`() {
        #expect(AppSettings(defaults: defaults).shouldCheckForUpdates == false)
    }
}
