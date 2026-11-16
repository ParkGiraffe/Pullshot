import PullshotKit
import SwiftUI

/// 회색 바탕 위에 썸네일을 받아 얹습니다. 칸이 화면을 벗어나면 받는 작업이 취소됩니다.
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
