import PullshotKit
import SwiftUI

struct Thumbnail: View {
    let capture: Capture
    @Environment(ThumbnailStore.self) private var store
    @State private var image: NSImage?

    var body: some View {
        Color.gray.opacity(0.2)
            .overlay {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .task(id: capture.id) {
                image = await store.image(for: capture)
            }
    }
}
