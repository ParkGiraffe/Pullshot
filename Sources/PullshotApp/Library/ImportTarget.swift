import Foundation
import PullshotKit

/// 오른쪽 칸에서 가져올 대상입니다. 모두 저장 위치로 옮기지만, 대상마다 둘 자리와 옮긴 기록에 남길 종류가 다릅니다.
enum ImportTarget {
    /// 보이는 캡처 가운데 새 항목입니다.
    case newItems
    /// 보이는 캡처 모두입니다. 같은 파일이 이미 있으면 옮길 때 건너뜁니다.
    case all
    /// 고른 캡처입니다.
    case selected

    /// 새 항목과 모두는 저장 위치(`options.baseFolder`)의 게임 이름 폴더에 원래 이름 그대로 둡니다.
    /// 폴더별로 나눌지와 파일 이름 규칙은 고른 것을 가져올 때만 따릅니다.
    func items(_ captures: [Capture], options: ExportOptions) -> [TransferItem] {
        switch self {
        case .newItems, .all:
            TransferItem.imports(captures, into: options.baseFolder)
        case .selected:
            TransferItem.exports(captures, options: options)
        }
    }

    /// 고른 것은 CLI의 `export`처럼 이름을 바꿔 둘 수 있어 옮긴 기록에 `exported`로 남깁니다.
    var kind: TransferKind {
        switch self {
        case .newItems, .all:
            .imported
        case .selected:
            .exported
        }
    }
}
