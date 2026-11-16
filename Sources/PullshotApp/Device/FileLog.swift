import Foundation
import PullshotKit
import Synchronization

/// 사용자가 이슈에 그대로 붙일 수 있는 로그 파일입니다. 그래서 파일 이름, 게임 이름, 경로, 일련번호는 쓰지 않고,
/// 오류는 `describe`로 종류와 코드만 남깁니다.
final class FileLog: Sendable {
    static let defaultFile = URL.libraryDirectory.appending(path: "Logs/Pullshot/pullshot.log")
    /// 이보다 큰 파일은 앱을 열 때 `pullshot.1.log`로 옮깁니다. 앞서 옮긴 파일은 덮어씁니다.
    static let maxSize = 5_000_000

    private static let timestamp = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    private let handle: Mutex<FileHandle?>

    init(file: URL = defaultFile) {
        handle = Mutex(Self.open(file))
    }

    /// 쓰지 못하면 앱을 멈추지 않고 그 줄을 통합 로그에 남깁니다.
    func write(_ line: String) {
        let data = Data("\(Date.now.formatted(Self.timestamp)) \(line)\n".utf8)
        let isWritten = handle.withLock { (try? $0?.write(contentsOf: data)) != nil }
        guard !isWritten else { return }
        Log.app.error("로그 파일에 쓰지 못한 줄: \(line, privacy: .public)")
    }

    /// 오류를 로그에 쓸 꼴로 바꿉니다. 이름과 경로가 든 값은 빼고 case 이름과 코드만 남깁니다.
    static func describe(_ error: any Error) -> String {
        switch error {
        case let error as SessionError:
            describe(error)
        case let error as TransportError:
            describe(error)
        case let error as ConsoleAccessError:
            describe(error)
        case is FolderMatchError:
            "unreadableFolder"
        default:
            "\((error as NSError).domain) \((error as NSError).code)"
        }
    }

    private static func describe(_ error: SessionError) -> String {
        switch error {
        case let .response(response, operation):
            String(format: "response(0x%04X, 0x%04X)", response.rawValue, operation.rawValue)
        case let .unexpectedContainer(kind, code):
            String(format: "unexpectedContainer(%d, 0x%04X)", kind, code)
        case let .transactionMismatch(expected, got):
            "transactionMismatch(\(expected), \(got))"
        case let .transport(error):
            "transport(\(describe(error)))"
        case .invalidated, .cancelled, .needsUSBReset:
            String(describing: error)
        case .destinationExists:
            "destinationExists"
        case let .sizeMismatch(expected, actual):
            "sizeMismatch(\(expected), \(actual))"
        }
    }

    private static func describe(_ error: TransportError) -> String {
        switch error {
        case .timedOut, .disconnected, .stalled:
            String(describing: error)
        case let .io(code):
            String(format: "io(0x%08X)", code)
        }
    }

    private static func describe(_ error: ConsoleAccessError) -> String {
        switch error {
        case let .heldByAnotherApp(code, owner):
            String(format: "heldByAnotherApp(0x%08X, %@)", code, owner ?? "unknown")
        case .noStillImageInterface, .missingEndpoints:
            String(describing: error)
        case let .other(code):
            String(format: "other(0x%08X)", code)
        }
    }

    private static func open(_ file: URL) -> FileHandle? {
        let fileManager = FileManager.default
        let path = file.path(percentEncoded: false)
        do {
            try fileManager.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            let size = (try? fileManager.attributesOfItem(atPath: path)[.size] as? NSNumber)?.intValue ?? 0
            if size > maxSize {
                let previous = file.deletingPathExtension().appendingPathExtension("1")
                    .appendingPathExtension(file.pathExtension)
                try? fileManager.removeItem(at: previous)
                try fileManager.moveItem(at: file, to: previous)
            }
            if !fileManager.fileExists(atPath: path) {
                fileManager.createFile(atPath: path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: file)
            try handle.seekToEnd()
            return handle
        } catch {
            Log.app.error("로그 파일을 열지 못했습니다: \(String(describing: error), privacy: .private)")
            return nil
        }
    }
}
