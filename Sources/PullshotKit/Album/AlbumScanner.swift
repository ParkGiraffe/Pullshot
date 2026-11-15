import Foundation

/// 앨범을 훑는 데 필요한 질의입니다. `Session`이 따르고, 테스트는 가짜 앨범으로 바꿉니다.
public protocol AlbumSource: AnyObject {
    func storageIDs() throws -> [UInt32]
    func objectHandles(storage: UInt32, parent: UInt32) throws -> [UInt32]
    func objectInfo(_ handle: UInt32) throws -> ObjectInfo
}

extension Session: AlbumSource {}

public struct SkippedObject: Equatable, Sendable {
    public var handle: UInt32
    public var reason: String
}

public struct AlbumScan: Equatable, Sendable {
    public var captures: [Capture]
    public var skipped: [SkippedObject]

    public init(captures: [Capture], skipped: [SkippedObject]) {
        self.captures = captures
        self.skipped = skipped
    }
}

/// 앨범 폴더를 따라 내려가며 캡처를 모읍니다. 스위치는 저장소 전체를 한 번에 달라는 평면 질의를 거부합니다.
public struct AlbumScanner {
    private let source: AlbumSource
    private let timeZone: TimeZone

    public init(source: AlbumSource, timeZone: TimeZone = .current) {
        self.source = source
        self.timeZone = timeZone
    }

    /// 객체 하나나 저장소 하나를 읽지 못하면 그것만 건너뛰고, 전송이 끊기면 멈춥니다.
    /// `progress`에는 지금까지 본 객체 수를 넘깁니다. 취소는 객체 사이에서 확인하므로 세션은 계속 쓸 수 있습니다.
    public func scan(progress: (Int) -> Void = { _ in }, isCancelled: () -> Bool = { false }) throws -> AlbumScan {
        var walk = Walk()
        for storage in try source.storageIDs() {
            let roots: [UInt32]
            do {
                roots = try source.objectHandles(storage: storage, parent: PTP.rootParent)
            } catch let SessionError.response(response, operation: _) {
                // 스위치는 앨범 저장소 하나지만, 쓸 수 없는 저장소가 섞여도 나머지는 훑습니다.
                Log.album.notice("저장소 0x\(String(storage, radix: 16), privacy: .public) 건너뜀: \(response.rawValue)")
                continue
            }
            try visit(roots, in: storage, gameFolder: nil, walk: &walk, progress: progress, isCancelled: isCancelled)
        }
        return AlbumScan(captures: walk.captures.sorted(by: Capture.newestFirst), skipped: walk.skipped)
    }

    private func visit(
        _ handles: [UInt32],
        in storage: UInt32,
        gameFolder: String?,
        walk: inout Walk,
        progress: (Int) -> Void,
        isCancelled: () -> Bool
    ) throws {
        for handle in handles {
            guard !isCancelled() else { throw SessionError.cancelled }
            walk.seen += 1
            progress(walk.seen)
            guard let info = try readOrSkip(handle, walk: &walk, { try source.objectInfo(handle) }) else { continue }
            guard info.isFolder else {
                record(info, handle: handle, in: storage, gameFolder: gameFolder, walk: &walk)
                continue
            }
            // 폴더가 자기나 조상을 다시 가리키는 기기에서도 끝나도록 한 번 본 폴더는 다시 내려가지 않습니다.
            guard walk.visitedFolders.insert(handle).inserted, let children = try readOrSkip(handle, walk: &walk, {
                try source.objectHandles(storage: storage, parent: handle)
            }) else { continue }
            let folder = Capture.isSafeFilename(info.filename) ? info.filename : nil
            try visit(
                children,
                in: storage,
                gameFolder: folder,
                walk: &walk,
                progress: progress,
                isCancelled: isCancelled
            )
        }
    }

    private func record(_ info: ObjectInfo, handle: UInt32, in storage: UInt32, gameFolder: String?, walk: inout Walk) {
        guard Capture.isSafeFilename(info.filename) else {
            return walk.skip(handle, "unsafe filename")
        }
        guard let kind = Self.kind(of: info) else {
            return walk.skip(handle, "not media")
        }
        walk.captures.append(Capture(
            handle: handle,
            storageID: storage,
            filename: info.filename,
            size: info.compressedSize == .max ? nil : UInt64(info.compressedSize),
            capturedAt: capturedAt(info),
            kind: kind,
            gameFolder: gameFolder
        ))
    }

    /// 기기가 OK가 아닌 응답을 보냈거나 데이터를 풀 수 없는 객체는 건너뛰고, 그 밖의 실패(전송, 세션)는 그대로 던집니다.
    private func readOrSkip<T>(_ handle: UInt32, walk: inout Walk, _ read: () throws -> T) throws -> T? {
        do {
            return try read()
        } catch let SessionError.response(response, operation: _) {
            walk.skip(handle, "response \(Session.hex(response.rawValue))")
        } catch let error as PTPDecodingError {
            walk.skip(handle, String(describing: error))
        }
        return nil
    }

    private func capturedAt(_ info: ObjectInfo) -> Date? {
        if let date = DateTimeString.parse(info.captureDate, timeZone: timeZone) {
            return date
        }
        // 스위치 캡처는 파일 이름이 찍은 시각(yyyyMMddHHmmss)으로 시작합니다.
        let digits = info.filename.prefix(14)
        guard digits.count == 14, digits.allSatisfy(\.isASCII), digits.allSatisfy(\.isNumber) else { return nil }
        return DateTimeString.parse("\(digits.prefix(8))T\(digits.suffix(6))", timeZone: timeZone)
    }

    /// 확장자로 정하고, 확장자가 없을 때만 PTP 형식을 봅니다.
    private static func kind(of info: ObjectInfo) -> Capture.Kind? {
        switch URL(filePath: info.filename).pathExtension.lowercased() {
        case "jpg", "jpeg", "png":
            .photo
        case "mp4", "mov":
            .video
        case "":
            kind(of: info.format)
        default:
            nil
        }
    }

    private static func kind(of format: PTP.ObjectFormat) -> Capture.Kind? {
        if [.exifJPEG, .png].contains(format) {
            return .photo
        }
        if [.mpeg, .mp4Container].contains(format) {
            return .video
        }
        return nil
    }
}

private struct Walk {
    var captures: [Capture] = []
    var skipped: [SkippedObject] = []
    var visitedFolders: Set<UInt32> = []
    var seen = 0

    mutating func skip(_ handle: UInt32, _ reason: String) {
        skipped.append(SkippedObject(handle: handle, reason: reason))
        Log.album.notice("객체 0x\(String(handle, radix: 16), privacy: .public) 건너뜀: \(reason, privacy: .public)")
    }
}
