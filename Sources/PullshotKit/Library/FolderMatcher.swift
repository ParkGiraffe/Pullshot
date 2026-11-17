import Foundation

public enum FolderMatchError: Error, Equatable {
    case unreadableFolder(URL)
}

public enum FolderMatcher {
    public static func captures(
        _ captures: [Capture],
        foundUnder folder: URL,
        isCancelled: () -> Bool = { false }
    ) throws -> [Capture] {
        try requireReadable(folder)
        guard !isCancelled() else { throw CancellationError() }
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey]
        let files = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants]
        )
        var sizesByName: [String: Set<UInt64>] = [:]
        while let file = files?.nextObject() as? URL {
            guard !isCancelled() else { throw CancellationError() }
            let values = try? file.resourceValues(forKeys: keys)
            guard values?.isRegularFile == true, let size = values?.fileSize else { continue }
            sizesByName[file.lastPathComponent, default: []].insert(UInt64(size))
        }

        return captures.filter { capture in
            capture.size.map { sizesByName[capture.filename]?.contains($0) == true } ?? false
        }
    }

    public static func requireReadable(_ folder: URL) throws {
        do {
            _ = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        } catch {
            throw FolderMatchError.unreadableFolder(folder)
        }
    }
}
