import Foundation

public struct ObjectInfo: Equatable, Sendable {
    public var storageID: UInt32
    public var format: PTP.ObjectFormat
    public var compressedSize: UInt32
    public var parent: UInt32
    public var filename: String
    public var captureDate: String
    public var modificationDate: String

    public var isFolder: Bool {
        format == .association
    }
}

public extension ObjectInfo {
    init(_ data: Data) throws {
        var reader = ByteReader(data)
        let storageID = try reader.u32()
        let format = try PTP.ObjectFormat(rawValue: reader.u16())
        _ = try reader.u16()
        let compressedSize = try reader.u32()
        _ = try reader.u16()
        _ = try reader.bytes(24)
        let parent = try reader.u32()
        _ = try reader.u16()
        _ = try reader.u32()
        _ = try reader.u32()
        try self.init(
            storageID: storageID,
            format: format,
            compressedSize: compressedSize,
            parent: parent,
            filename: reader.string(),
            captureDate: reader.string(),
            modificationDate: reader.string()
        )
    }
}
