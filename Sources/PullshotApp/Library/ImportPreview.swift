import Foundation
import PullshotKit

enum ImportPreview {
    static func lines(_ items: [TransferItem]) -> [String] {
        let hasManyFolders = Set(items.map(\.folder)).count > 1
        let lines = items.map { hasManyFolders ? "\($0.folder.lastPathComponent)/\($0.filename)" : $0.filename }
        guard lines.count > 5, let last = lines.last else { return lines }
        return lines.prefix(3) + ["…", last]
    }
}
