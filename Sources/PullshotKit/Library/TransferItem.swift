import Foundation

/// 옮길 캡처 하나와, 그 캡처를 둘 폴더와 이름입니다.
/// 실제 자리는 옮길 때 이미 있는 파일을 보고 정합니다(`DestinationNamer`).
public struct TransferItem: Equatable, Sendable {
    public var capture: Capture
    public var folder: URL
    public var filename: String
}

public enum ExportNaming: String, Sendable, CaseIterable {
    /// 기기의 원래 파일 이름 그대로입니다.
    case original
    /// 찍은 순서대로 번호를 붙입니다. 예: `001_20261114_211205.jpg`
    case numbered
}

public struct ExportOptions: Equatable, Sendable {
    public var baseFolder: URL
    /// 기준 폴더 아래 게임 이름 폴더를 만들어 넣습니다. 다른 게임을 내보내도 앞 게임 폴더에 섞이지 않습니다.
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

    /// `<root>/<게임 이름>/<원래 파일 이름>`입니다.
    static func imports(_ captures: [Capture], into root: URL = defaultImportFolder) -> [Self] {
        captures.map { Self(capture: $0, folder: root.appending(path: $0.gameName), filename: $0.filename) }
    }

    /// 폴더마다 찍은 순서로 둡니다. 번호를 붙이면 폴더마다 1부터 세고, 자릿수는 최소 3자리입니다.
    /// 폴더 순서는 입력에서 처음 나온 순서입니다.
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

    /// 찍은 시각을 모르면 번호 뒤에 원래 이름을 붙입니다. 확장자는 원래 파일의 것을 씁니다.
    private static func numberedName(_ capture: Capture, number: Int, width: Int, stamp: DateFormatter) -> String {
        let prefix = String(format: "%0\(width)d", number)
        guard let capturedAt = capture.capturedAt else { return "\(prefix)_\(capture.filename)" }
        let pathExtension = (capture.filename as NSString).pathExtension
        return "\(prefix)_\(stamp.string(from: capturedAt))" + (pathExtension.isEmpty ? "" : ".\(pathExtension)")
    }
}
