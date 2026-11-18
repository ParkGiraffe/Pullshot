import Foundation

public enum TransferKind: String, Codable, Sendable {
    case imported
    case exported
    case foundInFolder
    case markedAll

    var isActualTransfer: Bool {
        self == .imported || self == .exported
    }
}

public struct LedgerEntry: Codable, Equatable, Sendable {
    public var key: CaptureKey
    public var kind: TransferKind
    public var date: Date
}

public final class TransferLedger {
    public static let defaultDirectory = URL.applicationSupportDirectory.appending(path: "Pullshot")

    private static let newline = UInt8(ascii: "\n")

    private let file: URL
    private let answeredFile: URL
    private(set) var answeredSerialNumbers: Set<String> = []
    public private(set) var index = LedgerIndex()
    private var endsWithNewline = true

    public init(directory: URL = defaultDirectory) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        file = directory.appending(path: "transfers.jsonl")
        answeredFile = directory.appending(path: "answered-devices.json")
        if FileManager.default.fileExists(atPath: answeredFile.path(percentEncoded: false)) {
            do {
                let data = try Data(contentsOf: answeredFile)
                answeredSerialNumbers = try Set(JSONDecoder().decode([String].self, from: data))
            } catch {
                Log.library.error("답한 기기 파일을 읽지 못해 비우고 시작합니다: \(String(describing: error), privacy: .private)")
            }
        }
        guard FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) else { return }

        let data = try Data(contentsOf: file)
        endsWithNewline = data.last.map { $0 == Self.newline } ?? true
        var unreadable = 0
        for line in data.split(separator: Self.newline) {
            guard let entry = try? Self.decoder.decode(LedgerEntry.self, from: line) else {
                unreadable += 1
                continue
            }
            index.insert(entry)
        }
        if unreadable > 0 {
            Log.library.error("가져온 기록에서 읽지 못한 줄 \(unreadable, privacy: .public)개를 건너뜁니다")
        }
    }

    public func record(
        _ captures: [Capture],
        serialNumber: String,
        as kind: TransferKind,
        at date: Date = Date()
    ) throws {
        guard !captures.isEmpty else { return }
        let entries = captures.map { capture in
            LedgerEntry(key: CaptureKey(capture, serialNumber: serialNumber), kind: kind, date: date)
        }
        var lines = endsWithNewline ? Data() : Data([Self.newline])
        for entry in entries {
            try lines.append(Self.encoder.encode(entry) + [Self.newline])
        }
        try append(lines)
        endsWithNewline = true
        entries.forEach { index.insert($0) }
    }

    func markAnswered(_ serialNumber: String) throws {
        let answered = answeredSerialNumbers.union([serialNumber])
        try JSONEncoder().encode(answered.sorted()).write(to: answeredFile, options: .atomic)
        answeredSerialNumbers = answered
    }

    private func append(_ data: Data) throws {
        let descriptor = open(file.path(percentEncoded: false), O_WRONLY | O_APPEND | O_CREAT, 0o644)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        defer { close(descriptor) }
        let written = data.withUnsafeBytes { write(descriptor, $0.baseAddress, $0.count) }
        guard written == data.count else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    }

    private static let encoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
