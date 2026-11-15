import Foundation
@testable import PullshotKit

/// 고르기 테스트에 쓰는 캡처입니다. Kit 테스트 타깃의 픽스처는 이 타깃에서 쓸 수 없어 이름과 게임만 받는 것을 따로 둡니다.
func captureFixture(_ filename: String, game: String? = "젤다무쌍 봉인전기") -> Capture {
    Capture(
        handle: 1,
        storageID: 0x0001_0001,
        filename: filename,
        size: 5,
        capturedAt: nil,
        kind: .photo,
        gameFolder: game
    )
}
