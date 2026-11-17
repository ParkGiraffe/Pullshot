import Foundation

public struct ByteReader {
    private let data: Data
    private var offset = 0

    public init(_ data: Data) {
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

    public mutating func string() throws -> String {
        let count = try Int(u8())
        let units = try (0 ..< count).map { _ in try u16() }
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
