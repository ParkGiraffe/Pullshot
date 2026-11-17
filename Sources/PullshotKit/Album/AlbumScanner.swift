import Foundation

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

public struct AlbumScanner {
    private let source: AlbumSource
    private let timeZone: TimeZone

    public init(source: AlbumSource, timeZone: TimeZone = .current) {
        self.source = source
        self.timeZone = timeZone
    }

    public func scan(progress: (Int) -> Void = { _ in }, isCancelled: () -> Bool = { false }) throws -> AlbumScan {
        var walk = Walk()
        var rootError: SessionError?
        var hasReadableStorage = false
        for storage in try source.storageIDs() {
            let roots: [UInt32]
            do {
                roots = try source.objectHandles(storage: storage, parent: PTP.rootParent)
            } catch let SessionError.response(response, operation: operation) {
                Log.album.notice("저장소 0x\(String(storage, radix: 16), privacy: .public) 건너뜀: \(response.rawValue)")
                rootError = .response(response, operation: operation)
                continue
            }
            hasReadableStorage = true
            try visit(roots, in: storage, gameFolder: nil, walk: &walk, progress: progress, isCancelled: isCancelled)
        }
        if !hasReadableStorage, let rootError {
            throw rootError
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
        let digits = info.filename.prefix(14)
        guard digits.count == 14, digits.allSatisfy(\.isASCII), digits.allSatisfy(\.isNumber) else { return nil }
        return DateTimeString.parse("\(digits.prefix(8))T\(digits.suffix(6))", timeZone: timeZone)
    }

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
