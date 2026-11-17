import Foundation
import PullshotKit

enum ImportTarget {
    case newItems
    case all
    case selected

    func items(_ captures: [Capture], options: ExportOptions) -> [TransferItem] {
        switch self {
        case .newItems, .all:
            TransferItem.imports(captures, into: options.baseFolder)
        case .selected:
            TransferItem.exports(captures, options: options)
        }
    }

    var kind: TransferKind {
        switch self {
        case .newItems, .all:
            .imported
        case .selected:
            .exported
        }
    }
}
