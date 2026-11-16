import PullshotKit
import SwiftUI

@main
struct PullshotApp: App {
    /// 옮긴 기록을 열지 못하면 nil이고, 그때는 기기를 열지 않습니다.
    @State private var model = Self.makeModel()

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
            SettingsView()
                .tint(.pullshotAccent)
        }
    }

    private static func makeModel() -> LibraryModel? {
        let log = FileLog()
        let ledgerDirectory = UserDefaults.standard.string(forKey: SettingsKey.ledgerFolder.rawValue)
            .map { URL(filePath: $0, directoryHint: .isDirectory) } ?? TransferLedger.defaultDirectory
        do {
            return try LibraryModel(worker: DeviceWorker(ledgerDirectory: ledgerDirectory, log: log))
        } catch {
            log.write("옮긴 기록을 열지 못함: \(FileLog.describe(error))")
            return nil
        }
    }
}
