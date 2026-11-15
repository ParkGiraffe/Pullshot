import Foundation

/// PTP 데이터를 리틀 엔디언으로 이어 씁니다.
public struct ByteWriter {
    public private(set) var data = Data()

    public init() {}

    public mutating func u8(_ value: UInt8) {
        append(value)
    }

    public mutating func u16(_ value: UInt16) {
        append(value)
    }

    public mutating func u32(_ value: UInt32) {
        append(value)
    }

    public mutating func u64(_ value: UInt64) {
        append(value)
    }

    public mutating func bytes(_ value: Data) {
        data.append(value)
    }

    /// 빈 문자열은 개수 0 한 바이트이고, 나머지는 종결 문자까지 센 개수 뒤에 UTF-16LE로 씁니다.
    public mutating func string(_ text: String) {
        guard !text.isEmpty else {
            u8(0)
            return
        }
        let units = Array(text.utf16) + [0]
        precondition(units.count <= Int(UInt8.max), "PTP 문자열은 종결 문자를 포함해 255 코드 단위까지입니다")
        u8(UInt8(units.count))
        units.forEach { u16($0) }
    }

    public mutating func u16Array(_ values: [UInt16]) {
        u32(UInt32(values.count))
        values.forEach { u16($0) }
    }

    public mutating func u32Array(_ values: [UInt32]) {
        u32(UInt32(values.count))
        values.forEach { u32($0) }
    }

    private mutating func append(_ value: some FixedWidthInteger) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
}
