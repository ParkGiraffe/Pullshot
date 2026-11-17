import AppKit
import Quartz

final class PreviewPanelController: NSResponder {
    weak var model: LibraryModel?
    private var panel: QLPreviewPanel?

    var isOpen: Bool {
        panel?.isVisible == true
    }

    func open() {
        guard !isOpen else { return }
        if let window = NSApp.keyWindow, !Self.chain(from: window).contains(where: { $0 === self }) {
            nextResponder = window.nextResponder
            window.nextResponder = self
        }
        let panel = QLPreviewPanel.shared()
        panel?.updateController()
        panel?.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel?.orderOut(nil)
    }

    func reload() {
        panel?.reloadData()
    }

    private static func chain(from window: NSWindow) -> some Sequence<NSResponder> {
        sequence(first: window as NSResponder, next: \.nextResponder)
    }

    override nonisolated func acceptsPreviewPanelControl(_: QLPreviewPanel!) -> Bool {
        true
    }

    override nonisolated func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated {
            self.panel = panel
            panel.dataSource = self
            panel.delegate = self
        }
    }

    override nonisolated func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated {
            panel.dataSource = nil
            panel.delegate = nil
            self.panel = nil
            model?.previewClosed()
        }
    }
}

extension PreviewPanelController: @preconcurrency QLPreviewPanelDataSource {
    func numberOfPreviewItems(in _: QLPreviewPanel!) -> Int {
        model?.previewCapture == nil ? 0 : 1
    }

    func previewPanel(_: QLPreviewPanel!, previewItemAt _: Int) -> (any QLPreviewItem)! {
        guard let model, let capture = model.previewCapture else { return nil }
        return PreviewItem(previewItemURL: model.previewFile(for: capture), previewItemTitle: capture.filename)
    }
}

extension PreviewPanelController: @preconcurrency QLPreviewPanelDelegate {
    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        guard let key = PreviewKey(event) else { return false }
        switch key {
        case let .move(move):
            model?.movePreview(move)
        case .close:
            panel.orderOut(nil)
        }
        return true
    }
}

private final class PreviewItem: NSObject, QLPreviewItem {
    let previewItemURL: URL?
    let previewItemTitle: String?

    init(previewItemURL: URL?, previewItemTitle: String) {
        self.previewItemURL = previewItemURL
        self.previewItemTitle = previewItemTitle
    }
}
