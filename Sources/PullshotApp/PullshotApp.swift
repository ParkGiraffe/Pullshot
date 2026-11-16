import PullshotKit
import SwiftUI

@main
struct PullshotApp: App {
    /// 기록 창과 설정 창이 같은 설정을 보도록 하나만 만듭니다.
    @State private var settings: AppSettings
    /// 옮긴 기록을 열지 못하면 nil이고, 그때는 기기를 열지 않습니다.
    @State private var model: LibraryModel?

    init() {
        let settings = AppSettings()
        _settings = State(initialValue: settings)
        _model = State(initialValue: Self.makeModel(settings: settings))
    }

    var body: some Scene {
        Window("Pullshot", id: "library") {
            Group {
                if let model {
                    LibraryWindow(model: model)
                } else {
                    Text("옮긴 기록을 열지 못했습니다")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .tint(.pullshotAccent)
        }
        Settings {
            SettingsView(settings: settings)
                .tint(.pullshotAccent)
        }
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
