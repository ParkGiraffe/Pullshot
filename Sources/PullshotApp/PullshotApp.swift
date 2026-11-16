import SwiftUI

@main
struct PullshotApp: App {
    var body: some Scene {
        Window("Pullshot", id: "library") {
            LibraryWindow()
                .tint(.pullshotAccent)
        }
    }
}
