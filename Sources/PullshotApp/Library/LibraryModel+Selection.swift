import Foundation
import PullshotKit

/// 격자에서 고르기입니다. 미리보기 패널이 열려 있으면 기준 캡처를 따라가게 합니다.
extension LibraryModel {
    /// 격자나 미리보기 패널에서 고른 것을 바꿉니다. 끝난 옮기기 결과는 앞서 고른 것의 결과라 닫아, 결과 칸이 가져오기
    /// 단추 자리를 차지하지 않게 합니다. 기기가 빠져 고른 것을 지울 때는 여기를 거치지 않아 결과가 안내 화면에 남습니다.
    func select(_ selection: GridSelection) {
        guard selection != self.selection else { return }
        self.selection = selection
        dismissTransferResult()
        if previewPanel.isOpen {
            followAnchorInPreview()
        }
    }

    /// 보이는 캡처가 바뀌면 보이지 않게 된 캡처를 고른 것에서 뺍니다. 옮기기를 마쳐 새 항목에서 빠진 캡처도 여기로 오므로,
    /// 그 결과를 보이도록 끝난 옮기기 결과는 닫지 않습니다. 필터를 바꿀 때는 `filter(_:)`가 결과를 닫습니다.
    /// 미리보기 패널은 새 순서로 앞뒤 캡처를 다시 고릅니다.
    func keepVisible(_ order: [Capture.ID]) {
        selection.keep(order)
        if previewPanel.isOpen {
            followAnchorInPreview()
        }
    }
}

/// 미리보기 패널입니다. Finder처럼 기준 캡처를 따라가고, 패널에서 누른 화살표도 격자의 고른 칸을 옮깁니다.
/// 넘길 때는 썸네일을 먼저 보이고 원본을 받으면 바꾸며, 기준 캡처의 원본을 받은 뒤 앞뒤 사진의 원본을 받아 둡니다.
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

    /// 미리보기 패널이 기준 캡처를 보이게 합니다. 기준 캡처가 보이지 않으면 패널을 닫고, 멀어진 캡처의 받기는 취소합니다.
    /// 끝내는 중에는 새로 받지 않습니다. 끝내기는 시작할 때 모은 받기만 기다리므로, 그 뒤에 시작한 받기는 세션을 닫는
    /// 일을 늦춥니다.
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

    /// 받아 둔 원본이 없으면 받기를 시작합니다. `earlier`가 있으면 그 받기가 끝난 뒤에 원본을 받습니다.
    @discardableResult
    private func startPreview(_ capture: Capture, after earlier: Task<Void, Never>?) -> Task<Void, Never>? {
        guard previewOriginals[capture.id] == nil else { return nil }
        let task = Task { await loadPreview(capture, after: earlier) }
        previewTasks[capture.id] = task
        return task
    }

    /// 받아 둔 원본이 지워졌거나 크기가 다르면 그 캡처의 파일과 끝난 받기를 잊어 다시 받게 합니다.
    /// 미리보기 폴더는 같은 번들 ID의 다른 Pullshot(데모, 테스트)이 시작할 때도 지웁니다.
    private func forgetRemovedPreview(of capture: Capture) {
        guard let original = previewOriginals[capture.id], !DeviceWorker.hasPreview(of: capture, at: original) else {
            return
        }
        previewOriginals[capture.id] = nil
        previewThumbnails[capture.id] = nil
        previewTasks[capture.id] = nil
    }

    /// 썸네일 파일을 먼저 두고, `earlier`가 끝나면 기기에서 원본을 받아 원본으로 바꿉니다. 보고 있는 캡처면 그때마다
    /// 패널을 새로 고칩니다. 데모 캡처는 기기에 없어 썸네일만 둡니다.
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
