import Foundation
import PullshotKit

/// 격자에서 고르기입니다. 미리보기 패널이 열려 있으면 기준 캡처를 따라가게 합니다.
extension LibraryModel {
    /// 격자나 미리보기 패널에서 고른 것을 바꿉니다. 끝난 옮기기 결과는 앞서 고른 것의 결과라 닫아, 결과 칸이 내보내기
    /// 단추 자리를 차지하지 않게 합니다. 기기가 빠져 고른 것을 지울 때는 여기를 거치지 않아 결과가 안내 화면에 남습니다.
    func select(_ selection: GridSelection) {
        guard selection != self.selection else { return }
        self.selection = selection
        dismissTransferResult()
        if previewPanel.isOpen {
            followAnchorInPreview()
        }
    }

    /// 범위나 필터가 바뀌어 보이지 않게 된 캡처를 고른 것에서 뺍니다. 미리보기 패널은 새 순서로 앞뒤 캡처를 다시 고릅니다.
    func keepVisible(_ order: [Capture.ID]) {
        selection.keep(order)
        if previewPanel.isOpen {
            followAnchorInPreview()
        }
    }
}

/// 미리보기 패널입니다. Finder처럼 기준 캡처를 따라가고, 패널에서 누른 화살표도 격자의 고른 칸을 옮깁니다.
/// 넘길 때는 썸네일을 먼저 보이고 원본을 받으면 바꾸며, 앞뒤 한 장은 미리 받아 둡니다.
extension LibraryModel {
    /// 스페이스로 미리보기 패널을 열고 닫습니다.
    func togglePreview() {
        if previewPanel.isOpen {
            previewPanel.close()
        } else {
            preview()
        }
    }

    /// 기준 캡처를 미리보기 패널로 엽니다. 옮기는 중에는 미리보기 원본이 옮기기 뒤로 줄을 서 끝난 뒤에야 뜨므로 열지 않습니다.
    func preview() {
        guard !isShuttingDown, !isTransferring, selection.anchor != nil else { return }
        followAnchorInPreview()
        previewPanel.open()
    }

    /// 미리보기 패널에서 누른 화살표로 기준 캡처를 옮깁니다. 격자의 화살표와 같은 규칙이라 끝에서 멈춥니다.
    func movePreview(_ move: GridSelection.Move) {
        var moved = selection
        moved.move(move, columns: gridColumns, in: visibleCaptures.map(\.id))
        select(moved)
    }

    /// 미리보기 패널에 보일 파일입니다. 원본을 받기 전에는 썸네일 파일이고, 둘 다 없으면 nil입니다.
    func previewFile(for capture: Capture) -> URL? {
        previewOriginals[capture.id] ?? previewThumbnails[capture.id]
    }

    /// 미리보기 패널이 닫혔습니다. 받아 둔 파일은 다시 열 때 쓰도록 남깁니다.
    func previewClosed() {
        previewCapture = nil
        previewTasks.values.forEach { $0.cancel() }
        previewTasks = [:]
    }

    /// 미리보기 패널을 닫고 받던 미리보기를 취소합니다.
    func stopPreview() {
        previewPanel.close()
        previewClosed()
    }

    /// 미리보기 패널이 기준 캡처를 보이게 합니다. 기준 캡처와 앞뒤 한 장의 파일을 받고, 멀어진 캡처의 받기는 취소합니다.
    /// 기준 캡처가 보이지 않으면 패널을 닫습니다.
    private func followAnchorInPreview() {
        let order = visibleCaptures
        let targets = selection.previewTargets(in: order.map(\.id))
        let targetCaptures = targets.compactMap { id in order.first { $0.id == id } }
        guard let current = targetCaptures.first else {
            previewPanel.close()
            return
        }
        previewCapture = current
        for (id, task) in previewTasks where !targets.contains(id) {
            task.cancel()
        }
        previewTasks = previewTasks.filter { targets.contains($0.key) }
        for capture in targetCaptures where previewTasks[capture.id] == nil && previewOriginals[capture.id] == nil {
            previewTasks[capture.id] = Task { await loadPreview(capture) }
        }
        previewPanel.reload()
    }

    /// 썸네일 파일을 먼저 두고, 기기에서 원본을 받으면 원본으로 바꿉니다. 보고 있는 캡처면 그때마다 패널을 새로 고칩니다.
    /// 데모 캡처는 기기에 없어 썸네일만 둡니다.
    private func loadPreview(_ capture: Capture) async {
        if previewThumbnails[capture.id] == nil, let file = await thumbnails.previewFile(for: capture) {
            guard !Task.isCancelled else { return }
            previewThumbnails[capture.id] = file
            refreshPreview(of: capture)
        }
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
