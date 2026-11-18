import AppKit

@MainActor
final class UpdateChecker {
    private var isChecking = false

    private var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    func check(isAutomatic: Bool) {
        guard !isChecking else { return }
        isChecking = true
        Task {
            let current = currentVersion
            let result = await UpdateCheck.fetch(current: current)
            isChecking = false
            show(result, current: current, isAutomatic: isAutomatic)
        }
    }

    private func show(_ result: UpdateCheck, current: String, isAutomatic: Bool) {
        let alert = NSAlert()
        switch result {
        case let .available(version, page):
            alert.messageText = String(localized: "새 버전이 있습니다")
            alert.informativeText = String(localized: "새 버전은 Pullshot \(version)이고, 지금 사용 중인 버전은 \(current)입니다.")
            alert.addButton(withTitle: String(localized: "다운로드 페이지 열기"))
            alert.addButton(withTitle: String(localized: "나중에"))
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(page)
            }
            return
        case .upToDate:
            alert.messageText = String(localized: "최신 버전을 사용하고 있습니다")
            alert.informativeText = String(localized: "지금 사용 중인 버전은 \(current)입니다.")
        case .failed:
            alert.messageText = String(localized: "업데이트를 확인하지 못했습니다")
            alert.informativeText = String(localized: "인터넷 연결을 확인하고 잠시 뒤 다시 시도해 주세요.")
        }
        guard !isAutomatic else { return }
        alert.runModal()
    }
}
