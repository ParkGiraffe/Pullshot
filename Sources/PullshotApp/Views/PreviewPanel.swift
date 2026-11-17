import AppKit
import Quartz

/// 미리보기 패널(Quick Look)을 맡는 응답자입니다. 패널을 열 때 창의 응답자 사슬 끝에 붙어, 패널이 컨트롤러를 찾으면 나섭니다.
/// 패널에는 기준 캡처 한 장만 두고 화살표는 모델에 넘깁니다. 여러 장을 주면 패널의 앞뒤 단추와 모아 보기가 격자의 고른
/// 칸을 옮기지 않고 넘기고, 위아래 화살표로 격자 한 줄을 옮길 수 없기 때문입니다(Finder에서 한 장을 고르고 볼 때와 같음).
final class PreviewPanelController: NSResponder {
    weak var model: LibraryModel?
    /// 패널을 맡는 동안만 있습니다.
    private var panel: QLPreviewPanel?

    var isOpen: Bool {
        panel?.isVisible == true
    }

    /// 키 창의 응답자 사슬 끝에 붙고 패널을 엽니다. 이미 열려 있으면 그대로 둡니다.
    func open() {
        guard !isOpen else { return }
        if let window = NSApp.keyWindow, !Self.chain(from: window).contains(where: { $0 === self }) {
            nextResponder = window.nextResponder
            window.nextResponder = self
        }
        let panel = QLPreviewPanel.shared()
        // 패널은 창이 바뀔 때만 사슬을 다시 살피므로, 방금 붙은 것을 알립니다.
        panel?.updateController()
        panel?.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel?.orderOut(nil)
    }

    /// 보일 캡처나 파일이 바뀌었을 때 부릅니다.
    func reload() {
        panel?.reloadData()
    }

    private static func chain(from window: NSWindow) -> some Sequence<NSResponder> {
        sequence(first: window as NSResponder, next: \.nextResponder)
    }

    /// QuickLookUI는 이 메서드들에 액터를 적지 않았지만, 패널은 메인 스레드에서만 부릅니다.
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

    /// 패널은 앱에 하나뿐이라, 맡기를 끝내면 데이터 소스와 델리게이트를 비워 다음에 패널을 맡는 쪽이 이 컨트롤러에 묻지 않게 합니다.
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

/// 패널에 넘기는 한 장입니다. 원본을 받기 전에는 썸네일 파일을 가리키고, 제목은 늘 원래 파일 이름입니다.
private final class PreviewItem: NSObject, QLPreviewItem {
    let previewItemURL: URL?
    let previewItemTitle: String?

    init(previewItemURL: URL?, previewItemTitle: String) {
        self.previewItemURL = previewItemURL
        self.previewItemTitle = previewItemTitle
    }
}
