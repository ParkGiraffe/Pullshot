import Foundation

/// 전송 기록 한 줄입니다. JSON Lines로 한 줄에 하나씩 씁니다.
/// `dir`은 out(쓰기), in(읽기), in-error(읽기 실패), reset(장치 리셋)입니다.
struct TransferRecord: Codable, Equatable {
    var dir: String
    var hex: String?
    var error: String?
    var kind: String?
}

/// 감싼 전송에 모든 호출을 넘기면서 주고받은 바이트를 파일에 남깁니다. 실기기 덤프를 테스트 픽스처로 쓰려고 둡니다.
/// 기록에는 기기 일련번호와 사용자 캡처가 들어가므로 공개 리포에 올리지 않습니다.
public final class RecordingTransport: Transport {
    private let wrapped: Transport
    private let file: FileHandle

    public init(wrapping wrapped: Transport, to url: URL) throws {
        try Data().write(to: url)
        self.wrapped = wrapped
        file = try FileHandle(forWritingTo: url)
    }

    deinit {
        try? file.close()
    }

    public func write(_ data: Data, timeout: TimeInterval) throws {
        try append(TransferRecord(dir: "out", hex: data.hexString))
        try wrapped.write(data, timeout: timeout)
    }

    public func read(maxLength: Int, timeout: TimeInterval) throws -> Data {
        do {
            let data = try wrapped.read(maxLength: maxLength, timeout: timeout)
            try append(TransferRecord(dir: "in", hex: data.hexString))
            return data
        } catch let error as TransportError {
            try append(TransferRecord(dir: "in-error", error: error.recorded))
            throw error
        }
    }

    public func resetPTPDevice() throws {
        try reset("ptp") { try wrapped.resetPTPDevice() }
    }

    public func resetUSBDevice() throws {
        try reset("usb") { try wrapped.resetUSBDevice() }
    }

    public func close() {
        wrapped.close()
        try? file.synchronize()
    }

    private func reset(_ kind: String, _ body: () throws -> Void) throws {
        do {
            try body()
            try append(TransferRecord(dir: "reset", kind: kind))
        } catch let error as TransportError {
            try append(TransferRecord(dir: "reset", error: error.recorded, kind: kind))
            throw error
        }
    }

    private func append(_ record: TransferRecord) throws {
        try file.write(contentsOf: JSONEncoder().encode(record) + Data("\n".utf8))
    }
}

public enum ReplayError: Error, Equatable {
    case unexpectedWrite(index: Int)
    case unexpectedRead(index: Int)
    case unexpectedReset(index: Int)
    case exhausted
}

/// 기록을 순서대로 되풀이합니다. 쓰기는 기록과 바이트까지 같아야 하고, 읽기는 기록된 바이트나 오류를 돌려줍니다.
public final class ReplayTransport: Transport {
    private let records: [TransferRecord]
    private var index = 0

    public init(contentsOf url: URL) throws {
        records = try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n")
            .map { try JSONDecoder().decode(TransferRecord.self, from: Data($0.utf8)) }
    }

    public var isFinished: Bool {
        index == records.count
    }

    public func write(_ data: Data, timeout _: TimeInterval) throws {
        let (position, record) = try next()
        guard record.dir == "out",
              record.hex == data.hexString else { throw ReplayError.unexpectedWrite(index: position) }
    }

    public func read(maxLength _: Int, timeout _: TimeInterval) throws -> Data {
        let (position, record) = try next()
        if record.dir == "in-error", let error = record.error.flatMap(TransportError.init(recorded:)) {
            throw error
        }
        guard record.dir == "in", let data = record.hex.flatMap(Data.init(hexString:)) else {
            throw ReplayError.unexpectedRead(index: position)
        }
        return data
    }

    public func resetPTPDevice() throws {
        try replayReset("ptp")
    }

    public func resetUSBDevice() throws {
        try replayReset("usb")
    }

    public func close() {}

    private func replayReset(_ kind: String) throws {
        let (position, record) = try next()
        guard record.dir == "reset", record.kind == kind else { throw ReplayError.unexpectedReset(index: position) }
        if let error = record.error.flatMap(TransportError.init(recorded:)) {
            throw error
        }
    }

    private func next() throws -> (Int, TransferRecord) {
        guard index < records.count else { throw ReplayError.exhausted }
        defer { index += 1 }
        return (index, records[index])
    }
}

extension TransportError {
    var recorded: String {
        switch self {
        case .timedOut: "timedOut"
        case .disconnected: "disconnected"
        case .stalled: "stalled"
        case let .io(code): String(format: "io:0x%08X", code)
        }
    }

    init?(recorded: String) {
        switch recorded {
        case "timedOut": self = .timedOut
        case "disconnected": self = .disconnected
        case "stalled": self = .stalled
        default:
            guard recorded.hasPrefix("io:0x"), let code = UInt32(recorded.dropFirst(5), radix: 16) else { return nil }
            self = .io(code: code)
        }
    }
}

extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }

    init?(hexString: String) {
        guard hexString.count.isMultiple(of: 2) else { return nil }
        var bytes: [UInt8] = []
        var index = hexString.startIndex
        while index < hexString.endIndex {
            let next = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index ..< next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        self.init(bytes)
    }
}
