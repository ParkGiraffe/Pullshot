import AppKit

enum AppIcon: String, CaseIterable {
    case red
    case purple
    case shutter

    var resourceName: String {
        switch self {
        case .red: "icon-red-gamepad"
        case .purple: "icon-purple-gamepad"
        case .shutter: "icon-shutter"
        }
    }

    var image: NSImage? {
        Bundle.main.image(forResource: resourceName)
    }

    @MainActor func showInDock() {
        NSApp.applicationIconImage = self == .red ? nil : image
    }
}
