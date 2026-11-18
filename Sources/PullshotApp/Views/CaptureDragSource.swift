import AppKit

@MainActor
final class CaptureDragSource: NSObject, NSDraggingSource, NSFilePromiseProviderDelegate {
    private let drag: CaptureDrag
    private let model: LibraryModel
    private(set) var isDragging = false

    init(drag: CaptureDrag, model: LibraryModel) {
        self.drag = drag
        self.model = model
    }

    func begin(from view: NSView, with event: NSEvent, image: NSImage) {
        let provider = NSFilePromiseProvider(fileType: drag.fileType.identifier, delegate: self)
        let item = NSDraggingItem(pasteboardWriter: provider)
        let point = view.convert(event.locationInWindow, from: nil)
        let origin = NSPoint(x: point.x - image.size.width / 2, y: point.y - image.size.height / 2)
        item.setDraggingFrame(NSRect(origin: origin, size: image.size), contents: image)
        isDragging = true
        view.beginDraggingSession(with: [item], event: event, source: self)
    }

    func draggingSession(_: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? .copy : []
    }

    func draggingSession(_: NSDraggingSession, endedAt _: NSPoint, operation _: NSDragOperation) {
        isDragging = false
    }

    nonisolated func filePromiseProvider(_: NSFilePromiseProvider, fileNameForType _: String) -> String {
        drag.name
    }

    func filePromiseProvider(
        _: NSFilePromiseProvider,
        writePromiseTo url: URL,
        completionHandler: @escaping ((any Error)?) -> Void
    ) {
        nonisolated(unsafe) let completionHandler = completionHandler
        Task {
            await completionHandler(model.transfer(drag, to: url))
        }
    }
}
