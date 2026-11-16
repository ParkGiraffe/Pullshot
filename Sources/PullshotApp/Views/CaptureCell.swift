import PullshotKit
import SwiftUI

/// 격자의 한 칸입니다. 새 항목은 왼쪽 위에 주황 점, 영상은 왼쪽 아래에 재생 표시를 두고,
/// 고른 칸은 강조색 테두리와 오른쪽 아래 체크를 둡니다.
struct CaptureCell: View {
    let capture: Capture
    let isNew: Bool
    let isSelected: Bool

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
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.pullshotAccent, lineWidth: 3)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.pullshotAccent)
                        .overlay(Circle().stroke(.white, lineWidth: 1.5))
                        .padding(6)
                }
            }
            .clipShape(.rect(cornerRadius: 4))
    }
}
