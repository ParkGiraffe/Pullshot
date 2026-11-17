import Foundation
import PullshotKit

/// 고른 것을 가져오기 전에 오른쪽 칸에 보일 파일 이름입니다.
enum ExportPreview {
    /// 다섯 개까지는 모두, 여섯 개부터는 앞 세 개와 마지막 하나 사이를 `…`로 줄입니다.
    /// 폴더가 둘 이상이면 어느 폴더에 들어가는지 알 수 있게 `<폴더 이름>/<파일 이름>`으로 씁니다.
    static func lines(_ items: [TransferItem]) -> [String] {
        let hasManyFolders = Set(items.map(\.folder)).count > 1
        let lines = items.map { hasManyFolders ? "\($0.folder.lastPathComponent)/\($0.filename)" : $0.filename }
        guard lines.count > 5, let last = lines.last else { return lines }
        return lines.prefix(3) + ["…", last]
    }
}
