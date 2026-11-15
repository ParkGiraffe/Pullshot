import Foundation

public enum TransferKind: String, Codable, Sendable {
    case imported
    case exported
    /// 처음 연결 질문에서 고른 폴더에 이미 있던 캡처입니다.
    case foundInFolder
    /// 처음 연결 질문에서 모두 옮긴 것으로 표시한 캡처입니다.
    case markedAll

    /// 실제로 Mac에 옮긴 일인지입니다. 처음 연결 답으로 남긴 기록의 날짜는 옮긴 날이 아닙니다.
    var isActualTransfer: Bool {
        self == .imported || self == .exported
    }
}

public struct LedgerEntry: Codable, Equatable, Sendable {
    public var key: CaptureKey
    public var kind: TransferKind
    public var date: Date
}

/// 지난번 옮긴 날(그날 0시)과 그날 옮긴 캡처 수입니다.
public struct LastTransfer: Equatable, Sendable {
    public var day: Date
    public var count: Int
}

/// Mac으로 옮긴 캡처의 기록입니다. 기록에 없는 캡처가 새 항목입니다.
/// `transfers.jsonl`에 한 줄씩 덧붙여 쓰고, 열 때 한 번 읽어 색인을 만듭니다.
/// 기록에는 일련번호와 파일 이름이 들어 있어 통합 로그에 남기지 않습니다.
public final class TransferLedger {
    public static let defaultDirectory = URL.applicationSupportDirectory.appending(path: "Pullshot")

    private static let newline = UInt8(ascii: "\n")

    private let file: URL
    private var recorded: Set<CaptureKey> = []
    /// 가져오기나 내보내기로 마지막으로 옮긴 때입니다.
    private var lastTransferDates: [CaptureKey: Date] = [:]
    /// 앞서 꺼진 앱이 줄을 쓰다 말았으면 다음 줄을 새 줄에서 시작해야 합니다.
    private var endsWithNewline = true

    public init(directory: URL = defaultDirectory) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        file = directory.appending(path: "transfers.jsonl")
        guard FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) else { return }

        let data = try Data(contentsOf: file)
        endsWithNewline = data.last.map { $0 == Self.newline } ?? true
        var unreadable = 0
        for line in data.split(separator: Self.newline) {
            guard let entry = try? Self.decoder.decode(LedgerEntry.self, from: line) else {
                unreadable += 1
                continue
            }
            index(entry)
        }
        if unreadable > 0 {
            Log.library.error("옮긴 기록에서 읽지 못한 줄 \(unreadable, privacy: .public)개를 건너뜁니다")
        }
    }

    /// 한 번의 호출에서 만든 줄을 한 번에 덧붙입니다. 쓰지 못하면 던지고 색인도 바꾸지 않습니다.
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
        entries.forEach(index)
    }

    public func isTransferred(_ capture: Capture, serialNumber: String) -> Bool {
        recorded.contains(CaptureKey(capture, serialNumber: serialNumber))
    }

    public func newCaptures(_ captures: [Capture], serialNumber: String) -> [Capture] {
        captures.filter { !isTransferred($0, serialNumber: serialNumber) }
    }

    /// 가져오기나 내보내기로 마지막으로 옮긴 때입니다. 처음 연결 답으로만 기록된 캡처는 nil입니다.
    public func transferredAt(_ capture: Capture, serialNumber: String) -> Date? {
        lastTransferDates[CaptureKey(capture, serialNumber: serialNumber)]
    }

    /// 주어진 캡처 가운데 가장 늦게 옮긴 날과, 그날 옮긴 캡처 수입니다.
    public func lastTransfer(
        of captures: [Capture],
        serialNumber: String,
        calendar: Calendar = .current
    ) -> LastTransfer? {
        let dates = captures.compactMap { transferredAt($0, serialNumber: serialNumber) }
        guard let latest = dates.max() else { return nil }
        let day = calendar.startOfDay(for: latest)
        return LastTransfer(day: day, count: dates.count { calendar.isDate($0, inSameDayAs: day) })
    }

    private func index(_ entry: LedgerEntry) {
        recorded.insert(entry.key)
        guard entry.kind.isActualTransfer else { return }
        lastTransferDates[entry.key] = max(entry.date, lastTransferDates[entry.key] ?? entry.date)
    }

    /// 앱과 CLI가 함께 써도 줄이 섞이지 않도록 O_APPEND로 열어 한 번에 씁니다.
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
