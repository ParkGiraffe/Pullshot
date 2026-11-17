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
        settings.makesGameFolder = false
        settings.exportNaming = .numbered
        settings.isVerboseLog = true
        settings.appIcon = .shutter

        let reread = AppSettings(defaults: defaults)
        #expect(reread.importFolder == URL(filePath: "/tmp/스위치"))
        #expect(reread.makesGameFolder == false)
        #expect(reread.exportNaming == .numbered)
        #expect(reread.isVerboseLog)
        #expect(reread.appIcon == .shutter)
    }
}
