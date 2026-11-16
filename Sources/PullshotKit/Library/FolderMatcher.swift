import Foundation

public enum FolderMatchError: Error, Equatable {
    /// 폴더가 없거나 폴더가 아니거나 읽을 권한이 없습니다.
    case unreadableFolder(URL)
}

/// 처음 연결 질문의 "폴더에서 찾기"입니다. 폴더 구조는 따지지 않고, 파일 이름과 크기가 같은 파일이 있는 캡처를 찾습니다.
public enum FolderMatcher {
    /// 읽을 수 없는 하위 폴더는 건너뛰고, 패키지 안과 심볼릭 링크는 따라가지 않습니다. 크기를 모르는 캡처는 맞추지 않습니다.
    /// 취소는 파일마다 확인하고 `CancellationError`로 알립니다.
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

    /// 하위 폴더 오류는 건너뛰지만 고른 폴더 자체를 못 읽으면 던집니다. 0개를 찾은 것으로 끝내면
    /// 처음 연결 질문에 답한 기기로 남아, 다음 새 항목 받기가 모든 캡처를 다시 받습니다.
    public static func requireReadable(_ folder: URL) throws {
        do {
            _ = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        } catch {
            throw FolderMatchError.unreadableFolder(folder)
        }
    }
}
