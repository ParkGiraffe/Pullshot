import Foundation

public struct ThumbnailCache: Sendable {
    public static let defaultDirectory = URL.cachesDirectory.appending(path: "Pullshot/Thumbnails")

    private let directory: URL

    public init(directory: URL = defaultDirectory) {
        self.directory = directory
    }

    public func data(for key: CaptureKey) -> Data? {
        guard let file = file(for: key) else { return nil }
        return try? Data(contentsOf: file)
    }

    public func store(_ data: Data, for key: CaptureKey) {
        guard let file = file(for: key) else { return }
        do {
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: file, options: .atomic)
        } catch {
            Log.library
                .error(
                    "썸네일을 저장하지 못했습니다: \(file.path, privacy: .private) \(String(describing: error), privacy: .private)"
                )
        }
    }

    private func file(for key: CaptureKey) -> URL? {
        let folder = key.gameFolder.map { "g-\($0)" } ?? "root"
        guard [key.serialNumber, folder, key.filename].allSatisfy(Capture.isSafeFilename) else { return nil }
        let size = key.size.map(String.init) ?? "unknown"
        return directory.appending(path: key.serialNumber).appending(path: folder)
            .appending(path: "\(key.filename)-\(size)")
    }
}
