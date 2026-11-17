import Foundation

public struct TransferItem: Equatable, Sendable {
    public var capture: Capture
    public var folder: URL
    public var filename: String
}

public enum ExportNaming: String, Sendable, CaseIterable {
    case original
    case numbered
}

public struct ExportOptions: Equatable, Sendable {
    public var baseFolder: URL
    public var makesGameFolder: Bool
    public var naming: ExportNaming

    public init(baseFolder: URL, makesGameFolder: Bool = true, naming: ExportNaming = .original) {
        self.baseFolder = baseFolder
        self.makesGameFolder = makesGameFolder
        self.naming = naming
    }
}

public extension TransferItem {
    static let defaultImportFolder = URL.picturesDirectory.appending(path: "Pullshot")

    static func imports(_ captures: [Capture], into root: URL = defaultImportFolder) -> [Self] {
        captures.map { Self(capture: $0, folder: root.appending(path: $0.gameName), filename: $0.filename) }
    }

    static func exports(_ captures: [Capture], options: ExportOptions, timeZone: TimeZone = .current) -> [Self] {
        var folders: [URL] = []
        var capturesByFolder: [URL: [Capture]] = [:]
        for capture in captures {
            let folder = options.makesGameFolder
                ? options.baseFolder.appending(path: capture.gameName)
                : options.baseFolder
            if capturesByFolder[folder] == nil {
                folders.append(folder)
            }
            capturesByFolder[folder, default: []].append(capture)
        }
        let stamp = DateFormatter()
        stamp.locale = Locale(identifier: "en_US_POSIX")
        stamp.timeZone = timeZone
        stamp.dateFormat = "yyyyMMdd_HHmmss"

        return folders.flatMap { folder in
            let ordered = capturesByFolder[folder, default: []].sorted(by: Capture.oldestFirst)
            let width = max(3, String(ordered.count).count)
            return ordered.enumerated().map { offset, capture in
                let filename = switch options.naming {
                case .original:
                    capture.filename
                case .numbered:
                    numberedName(capture, number: offset + 1, width: width, stamp: stamp)
                }
                return Self(capture: capture, folder: folder, filename: filename)
            }
        }
    }

    private static func numberedName(_ capture: Capture, number: Int, width: Int, stamp: DateFormatter) -> String {
        let prefix = String(format: "%0\(width)d", number)
        guard let capturedAt = capture.capturedAt else { return "\(prefix)_\(capture.filename)" }
        let pathExtension = (capture.filename as NSString).pathExtension
        return "\(prefix)_\(stamp.string(from: capturedAt))" + (pathExtension.isEmpty ? "" : ".\(pathExtension)")
    }
}
