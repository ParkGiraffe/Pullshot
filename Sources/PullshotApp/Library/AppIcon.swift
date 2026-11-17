import AppKit

/// 설정에서 고르는 앱 아이콘입니다. 셋 모두 번들의 `Contents/Resources`에 `.icns`로 들어 있고, 빨강이 Finder와
/// Launchpad에 보이는 번들 기본 아이콘(`CFBundleIconFile`)입니다. 고른 아이콘은 Dock과 앱 전환기에만 보입니다.
/// 번들 안 파일을 바꾸면 ad-hoc 서명이 깨지기 때문입니다.
enum AppIcon: String, CaseIterable {
    case red
    case purple
    case shutter

    /// 번들의 `.icns` 이름입니다. `make app`이 같은 이름의 `design/app-icon` 그림으로 만듭니다.
    var resourceName: String {
        switch self {
        case .red: "icon-red-gamepad"
        case .purple: "icon-purple-gamepad"
        case .shutter: "icon-shutter"
        }
    }

    /// Dock에 따로 보일 아이콘의 이름입니다. 빨강은 번들 기본 아이콘이라 nil이고, 그때는 기본 아이콘으로 되돌립니다.
    var dockIconName: String? {
        self == .red ? nil : resourceName
    }

    /// 번들에서 읽은 아이콘입니다. 번들 밖에서 실행하면(`swift run`) nil입니다.
    var image: NSImage? {
        Bundle.main.image(forResource: resourceName)
    }

    /// Dock과 앱 전환기의 아이콘을 바꿉니다. AppKit은 nil을 받으면 번들 기본 아이콘으로 되돌립니다.
    @MainActor func showInDock() {
        NSApp.applicationIconImage = dockIconName.flatMap(Bundle.main.image(forResource:))
    }
}
