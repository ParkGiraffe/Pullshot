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
                    Text("옮긴 기록을 열지 못했습니다")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    /// 옮긴 기록을 열지 못하면 nil이고, 그때는 기기를 열지 않습니다.
    private(set) lazy var model = Self.makeModel(settings: settings)

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

    private static func makeModel(settings: AppSettings) -> LibraryModel? {
        let log = FileLog()
        let ledgerDirectory = UserDefaults.standard.string(forKey: SettingsKey.ledgerFolder.rawValue)
            .map { URL(filePath: $0, directoryHint: .isDirectory) } ?? TransferLedger.defaultDirectory
        do {
            let worker = try DeviceWorker(ledgerDirectory: ledgerDirectory, log: log)
            return LibraryModel(worker: worker, settings: settings)
        } catch {
            log.write("옮긴 기록을 열지 못함: \(FileLog.describe(error))")
            return nil
        }
    }
}
