import AppKit
import PullshotKit
import SwiftUI

@main
struct PullshotApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        Window("Pullshot", id: "library") {
            Group {
                if let model = appDelegate.model {
                    LibraryWindow(model: model)
                } else {
                    ContentUnavailableView {
                        Label("옮긴 기록을 열지 못했습니다", systemImage: "exclamationmark.triangle")
                    } description: {
                        let folder = appDelegate.ledgerDirectory.abbreviatedPath
                        Text("\(folder) 폴더가 있는지, 쓸 권한이 있는지 확인해 주세요. 도움말 메뉴의 로그 파일 보기에서 자세한 내용을 볼 수 있습니다.")
                    }
                }
            }
            .tint(.pullshotAccent)
        }
        .commands {
            CommandGroup(replacing: .help) {
                Button("로그 파일 보기", action: showLogFile)
            }
        }
        Settings {
            SettingsView(settings: appDelegate.settings)
                .tint(.pullshotAccent)
        }
    }

    /// 로그 파일을 Finder에서 고릅니다. 아직 파일이 없으면 로그 폴더를 엽니다.
    private func showLogFile() {
        let file = FileLog.defaultFile
        if FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) {
            NSWorkspace.shared.activateFileViewerSelecting([file])
        } else {
            NSWorkspace.shared.open(file.deletingLastPathComponent())
        }
    }
}

/// 끝낼 때 기기 일을 정리합니다. 화면과 끝내기가 같은 모델을 쓰도록 설정과 모델을 여기서 만들어 `PullshotApp`에 내줍니다.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 기록 창과 설정 창이 같은 설정을 보도록 하나만 만듭니다.
    let settings = AppSettings()
    /// 실행 인자 `-ledgerFolder <경로>`로 바꿀 수 있습니다. 기록을 열지 못하면 화면에 이 폴더를 보입니다.
    let ledgerDirectory = UserDefaults.standard.string(forKey: SettingsKey.ledgerFolder.rawValue)
        .map { URL(filePath: $0, directoryHint: .isDirectory) } ?? TransferLedger.defaultDirectory
    /// 옮긴 기록을 열지 못하면 nil이고, 그때는 기기를 열지 않습니다.
    private(set) lazy var model = Self.makeModel(ledgerDirectory: ledgerDirectory, settings: settings)

    /// Dock은 번들 기본 아이콘으로 앱을 열므로, 설정에서 고른 아이콘으로 바꿉니다.
    func applicationDidFinishLaunching(_: Notification) {
        settings.appIcon.showInDock()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        true
    }

    /// 열린 세션이 있으면 하던 일을 마치고 세션을 닫은 뒤 끝냅니다. 10초 안에 마치지 못하면 기다리지 않고 끝냅니다.
    /// 열린 세션이 없으면 미리보기 원본만 지우고 바로 끝냅니다.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model, model.hasOpenSession else {
            try? FileManager.default.removeItem(at: DeviceWorker.previewFolder)
            return .terminateNow
        }
        Task {
            await Self.wait(for: Task { await model.shutdown() }, atMost: .seconds(10))
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    /// `cleanup`이 끝나거나 `limit`이 지나면 돌아옵니다. 시간이 지나도 `cleanup`은 취소하지 않고 앱과 함께 끝나게 둡니다.
    static func wait(for cleanup: Task<Void, Never>, atMost limit: Duration) async {
        let (finished, continuation) = AsyncStream<Void>.makeStream()
        let timer = Task {
            try? await Task.sleep(for: limit)
            continuation.finish()
        }
        Task {
            await cleanup.value
            continuation.finish()
        }
        for await _ in finished {}
        timer.cancel()
    }

    private static func makeModel(ledgerDirectory: URL, settings: AppSettings) -> LibraryModel? {
        let log = FileLog()
        do {
            let worker = try DeviceWorker(ledgerDirectory: ledgerDirectory, log: log)
            return LibraryModel(worker: worker, settings: settings)
        } catch {
            log.write("옮긴 기록을 열지 못함: \(FileLog.describe(error))")
            return nil
        }
    }
}
