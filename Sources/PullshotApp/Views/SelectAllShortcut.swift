import AppKit
import Carbon.HIToolbox
import SwiftUI

struct SelectAllShortcut: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context _: Context) -> ShortcutView {
        ShortcutView()
    }

    func updateNSView(_ view: ShortcutView, context _: Context) {
        view.action = action
    }

    final class ShortcutView: NSView {
        var action: () -> Void = {}
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, isSelectAll(event) else { return event }
                action()
                return nil
            }
        }

        private func isSelectAll(_ event: NSEvent) -> Bool {
            guard event.window === window,
                  !(window?.firstResponder is NSText),
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                  let key = event.charactersIgnoringModifiers?.lowercased()
            else { return false }
            return key == "a" || (!key.allSatisfy(\.isASCII) && event.keyCode == UInt16(kVK_ANSI_A))
        }
    }
}
