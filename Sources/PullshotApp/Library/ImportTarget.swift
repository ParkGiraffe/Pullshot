import Foundation
import PullshotKit

enum ImportTarget {
    case new
    case all
    case selected

    func items(_ captures: [Capture], options: ExportOptions) -> [TransferItem] {
        switch self {
        case .new, .all:
            TransferItem.imports(captures, into: options.baseFolder)
        case .selected:
            TransferItem.exports(captures, options: options)
        }
    }

    var kind: TransferKind {
        switch self {
        case .new, .all:
            .imported
        case .selected:
            .exported
        }
    }
}
