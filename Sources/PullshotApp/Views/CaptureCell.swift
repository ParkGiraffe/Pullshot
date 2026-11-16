import PullshotKit
import SwiftUI

/// 격자의 한 칸입니다. 새 항목은 왼쪽 위에 주황 점, 영상은 왼쪽 아래에 재생 표시를 둡니다.
struct CaptureCell: View {
    let capture: Capture
    let isNew: Bool

    var body: some View {
        Thumbnail(capture: capture)
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay(alignment: .topLeading) {
                if isNew {
                    Circle()
                        .fill(Color.newCapture)
                        .overlay(Circle().stroke(.white, lineWidth: 1.5))
                        .frame(width: 8, height: 8)
                        .padding(6)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if capture.kind == .video {
                    Image(systemName: "play.fill")
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                        .padding(6)
                }
            }
            .clipShape(.rect(cornerRadius: 4))
    }
}
