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

extension LibraryModel {
    func togglePreview() {
        if previewPanel.isOpen {
            previewPanel.close()
        } else {
            preview()
        }
    }

    func preview() {
        guard !isShuttingDown, !isTransferring, selection.anchor != nil else { return }
        followAnchorInPreview()
        previewPanel.open()
    }

    func movePreview(_ move: GridSelection.Move) {
        var moved = selection
        moved.move(move, columns: gridColumns, in: visibleCaptures.map(\.id))
        select(moved)
    }

    func previewFile(for capture: Capture) -> URL? {
        previewOriginals[capture.id] ?? previewThumbnails[capture.id]
    }

    func previewClosed() {
        previewCapture = nil
        previewTasks.values.forEach { $0.cancel() }
        previewTasks = [:]
    }

    func stopPreview() {
        previewPanel.close()
        previewClosed()
    }

    private func followAnchorInPreview() {
        guard !isShuttingDown else { return }
        let targets = selection.previewTargets(in: visibleCaptures)
        guard let current = targets.first else {
            previewPanel.close()
            return
        }
        previewCapture = current
        let targetIDs = Set(targets.map(\.id))
        for (id, task) in previewTasks where !targetIDs.contains(id) {
            task.cancel()
        }
        previewTasks = previewTasks.filter { targetIDs.contains($0.key) }
        targets.forEach(forgetRemovedPreview(of:))
        let currentTask = previewTasks[current.id] ?? startPreview(current, after: nil)
        for neighbor in targets.dropFirst() where previewTasks[neighbor.id] == nil {
            startPreview(neighbor, after: currentTask)
        }
        previewPanel.reload()
    }

    @discardableResult
    private func startPreview(_ capture: Capture, after earlier: Task<Void, Never>?) -> Task<Void, Never>? {
        guard previewOriginals[capture.id] == nil else { return nil }
        let task = Task { await loadPreview(capture, after: earlier) }
        previewTasks[capture.id] = task
        return task
    }

    private func forgetRemovedPreview(of capture: Capture) {
        guard let original = previewOriginals[capture.id], !DeviceWorker.hasPreview(of: capture, at: original) else {
            return
        }
        previewOriginals[capture.id] = nil
        previewThumbnails[capture.id] = nil
        previewTasks[capture.id] = nil
    }

    private func loadPreview(_ capture: Capture, after earlier: Task<Void, Never>?) async {
        if previewThumbnails[capture.id] == nil, let file = await thumbnails.previewFile(for: capture) {
            guard !Task.isCancelled else { return }
            previewThumbnails[capture.id] = file
            refreshPreview(of: capture)
        }
        await earlier?.value
        guard !isDemo, !Task.isCancelled else { return }
        do {
            let file = try await worker.preview(capture)
            guard !Task.isCancelled else { return }
            previewOriginals[capture.id] = file
            refreshPreview(of: capture)
        } catch {
            guard !Task.isCancelled else { return }
            worker.log.write("미리보기를 받지 못함: \(FileLog.describe(error))")
            await reopenIfSessionLost()
        }
    }

    private func refreshPreview(of capture: Capture) {
        if previewCapture?.id == capture.id {
            previewPanel.reload()
        }
    }
}
