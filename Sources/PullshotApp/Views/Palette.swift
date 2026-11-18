import SwiftUI

extension Color {
    static let pullshotAccent = Color(red: 0xE6 / 255, green: 0x00 / 255, blue: 0x12 / 255)
    static let newCapture = Color(red: 0xFF / 255, green: 0x9F / 255, blue: 0x2E / 255)
}

extension View {
    func accentTintWhenEnabled() -> some View {
        modifier(AccentTintWhenEnabled())
    }
}

private struct AccentTintWhenEnabled: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content.tint(isEnabled ? .pullshotAccent : .gray)
    }
}
