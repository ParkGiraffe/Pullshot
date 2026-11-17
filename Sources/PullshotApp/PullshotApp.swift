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
        .defaultSize(width: 1200, height: 760)
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

    private func showLogFile() {
        let file = FileLog.defaultFile
        if FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) {
            NSWorkspace.shared.activateFileViewerSelecting([file])
        } else {
            NSWorkspace.shared.open(file.deletingLastPathComponent())
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    let ledgerDirectory = UserDefaults.standard.string(forKey: SettingsKey.ledgerFolder.rawValue)
        .map { URL(filePath: $0, directoryHint: .isDirectory) } ?? TransferLedger.defaultDirectory
    private(set) lazy var model = Self.makeModel(ledgerDirectory: ledgerDirectory, settings: settings)

    func applicationDidFinishLaunching(_: Notification) {
        settings.appIcon.showInDock()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        true
    }

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
