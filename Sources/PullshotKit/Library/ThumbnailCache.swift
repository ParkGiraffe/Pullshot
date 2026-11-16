import Foundation

/// 기기에서 받은 썸네일을 디스크에 둡니다. 스위치 2 앨범은 캡처가 3천 개가 넘고 GetThumb 한 번에 15~19KB라
/// 연결할 때마다 다시 받지 않게 합니다. 읽기 실패는 없는 것으로, 쓰기 실패는 로그만 남깁니다.
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

    /// `<일련번호>/<폴더>/<파일 이름>-<크기>`입니다. 기기가 보낸 이름이 폴더 밖을 가리키면 nil입니다.
    private func file(for key: CaptureKey) -> URL? {
        let folder = key.gameFolder.map { "g-\($0)" } ?? "root"
        guard [key.serialNumber, folder, key.filename].allSatisfy(Capture.isSafeFilename) else { return nil }
        let size = key.size.map(String.init) ?? "unknown"
        return directory.appending(path: key.serialNumber).appending(path: folder)
            .appending(path: "\(key.filename)-\(size)")
    }
}
