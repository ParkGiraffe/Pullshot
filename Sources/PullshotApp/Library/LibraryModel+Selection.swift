import Foundation
import PullshotKit

extension LibraryModel {
    func select(_ selection: GridSelection) {
        guard selection != self.selection else { return }
        self.selection = selection
        dismissTransferResult()
        if previewPanel.isOpen {
            followAnchorInPreview()
        }
    }

    func keepVisible(_ order: [Capture.ID]) {
        selection.keep(order)
        if previewPanel.isOpen {
            followAnchorInPreview()
        }
    }
}
