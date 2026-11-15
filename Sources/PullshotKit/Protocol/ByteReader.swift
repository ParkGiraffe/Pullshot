import Foundation

/// PTP 데이터를 리틀 엔디언으로 앞에서부터 읽습니다.
public struct ByteReader {
    private let data: Data
    private var offset = 0

    public init(_ data: Data) {
        // 잘라 낸 Data는 시작 인덱스가 0이 아닐 수 있어 새로 담아 0부터 셉니다.
        self.data = Data(data)
    }

    public var remaining: Int {
        data.count - offset
    }

    public mutating func u8() throws -> UInt8 {
        try integer()
    }

    public mutating func u16() throws -> UInt16 {
        try integer()
    }

    public mutating func u32() throws -> UInt32 {
        try integer()
    }

    public mutating func u64() throws -> UInt64 {
        try integer()
    }

    public mutating func bytes(_ count: Int) throws -> Data {
        try require(count)
        defer { offset += count }
        return data.subdata(in: offset ..< offset + count)
    }

    /// PTP 문자열: 종결 문자를 포함한 UTF-16 코드 단위 수(1바이트) 뒤에 UTF-16LE 코드 단위가 옵니다.
    public mutating func string() throws -> String {
        let count = try Int(u8())
        let units = try (0 ..< count).map { _ in try u16() }
        // 종결 문자를 빠뜨리는 기기도 있어 마지막이 0일 때만 떼어 냅니다.
        let text = units.last == 0 ? units.dropLast() : units[...]
        guard let decoded = String(validating: text, as: UTF16.self) else { throw PTPDecodingError.badString }
        return decoded
    }

    public mutating func u16Array() throws -> [UInt16] {
        try array()
    }

    public mutating func u32Array() throws -> [UInt32] {
        try array()
    }

    private mutating func array<T: FixedWidthInteger>() throws -> [T] {
        let count = try Int(u32())
        // 깨진 개수(예: 0xFFFFFFFF)로 큰 배열을 잡지 않도록 남은 바이트로 먼저 확인합니다.
        try require(count * MemoryLayout<T>.size)
        return try (0 ..< count).map { _ in try integer() }
    }

    private mutating func integer<T: FixedWidthInteger>() throws -> T {
        let size = MemoryLayout<T>.size
        try require(size)
        defer { offset += size }
        return data[offset ..< offset + size].reversed().reduce(T.zero) { $0 << 8 | T($1) }
    }

    private func require(_ count: Int) throws {
        guard count <= remaining else { throw PTPDecodingError.truncated(needed: count, available: remaining) }
    }
}
