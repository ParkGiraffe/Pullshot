import Foundation
import PullshotKit
import Testing
@testable import PullshotApp

@Suite("AppSettings 테스트")
@MainActor
struct AppSettingsTests {
    let defaults = defaultsFixture()

    @Test func `실행 인자로 준 NO는 게임 이름 폴더를 끈 것으로 읽는다`() {
        // 실행 인자 `-makesGameFolder NO`는 Bool이 아니라 문자열로 들어옵니다.
        defaults.set("NO", forKey: SettingsKey.makesGameFolder.rawValue)
        #expect(AppSettings(defaults: defaults).makesGameFolder == false)
    }

    @Test func `고른 적 없는 설정은 기본값으로 읽는다`() {
        let settings = AppSettings(defaults: defaults)
        #expect(settings.importFolder == TransferItem.defaultImportFolder)
        #expect(settings.exportFolder == nil)
        #expect(settings.makesGameFolder)
        #expect(settings.exportNaming == .original)
        #expect(settings.isVerboseLog == false)
    }

    @Test func `바꾼 설정은 다시 읽어도 남는다`() {
        let settings = AppSettings(defaults: defaults)
        settings.importFolder = URL(filePath: "/tmp/스위치")
        settings.exportFolder = URL(filePath: "/tmp/블로그")
        settings.makesGameFolder = false
        settings.exportNaming = .numbered
        settings.isVerboseLog = true

        let reread = AppSettings(defaults: defaults)
        #expect(reread.importFolder == URL(filePath: "/tmp/스위치"))
        #expect(reread.exportFolder == URL(filePath: "/tmp/블로그"))
        #expect(reread.makesGameFolder == false)
        #expect(reread.exportNaming == .numbered)
        #expect(reread.isVerboseLog)
    }
}
