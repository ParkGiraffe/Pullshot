import Foundation
import Testing
@testable import PullshotApp

@Suite("AppIcon 테스트")
struct AppIconTests {
    @Test func `번들 기본 아이콘은 빨강이다`() throws {
        #expect(try infoPlist()["CFBundleIconFile"] as? String == "icon-red-gamepad")
        #expect(AppIcon.red.resourceName == "icon-red-gamepad")
    }

    @Test func `빨강을 고르면 Dock 아이콘을 번들 기본 아이콘으로 되돌린다`() {
        #expect(AppIcon.red.dockIconName == nil)
    }

    @Test func `보라와 셔터 프레임은 번들의 아이콘 파일을 Dock에 보인다`() {
        #expect(AppIcon.purple.dockIconName == "icon-purple-gamepad")
        #expect(AppIcon.shutter.dockIconName == "icon-shutter")
    }

    @Test func `아이콘마다 큰 그림과 작은 크기용 그림이 있다`() {
        for icon in AppIcon.allCases {
            for suffix in ["", "-small"] {
                let file = appIconDesignFolder.appending(path: "\(icon.resourceName)\(suffix).png")
                #expect(FileManager.default.fileExists(atPath: file.path(percentEncoded: false)), "\(file)")
            }
        }
    }
}
