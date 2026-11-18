import AppKit
import PullshotKit
import UniformTypeIdentifiers

extension LibraryModel {
    func drag(_ capture: Capture) {
        guard !isTransferring, dragSource?.isDragging != true,
              let event = NSApp.currentEvent, event.type == .leftMouseDragged,
              let view = event.window?.contentView
        else { return }
        if !selection.selected.contains(capture.id) {
            var only = selection
            only.click(capture.id, .only, in: [capture.id])
            select(only)
        }
        let drag = CaptureDrag(
            captures: selectedCaptures,
            shouldMakeGameFolder: settings.shouldMakeGameFolder,
            naming: settings.importNaming
        )
        let source = CaptureDragSource(drag: drag, model: self)
        dragSource = source
        source.begin(from: view, with: event, image: dragImage(of: drag))
    }

    func transfer(_ drag: CaptureDrag, to destination: URL) async -> (any Error)? {
        let folder = drag.isFolder ? destination : destination.deletingLastPathComponent()
        guard let task = startTransfer(drag.items(at: destination), as: .exported, into: folder) else {
            return CocoaError(.fileWriteUnknown)
        }
        await task.value
        return transferRun?.errorMessage == nil ? nil : CocoaError(.fileWriteUnknown)
    }

    private func dragImage(of drag: CaptureDrag) -> NSImage {
        guard !drag.isFolder, let thumbnail = drag.captures.first.flatMap(thumbnails.cachedImage) else {
            let icon = NSWorkspace.shared.icon(for: drag.fileType)
            icon.size = NSSize(width: 64, height: 64)
            return icon
        }
        let width = 160.0
        let size = NSSize(width: width, height: width * thumbnail.size.height / max(thumbnail.size.width, 1))
        return NSImage(size: size, flipped: false) { rect in
            thumbnail.draw(in: rect)
            return true
        }
    }
}
