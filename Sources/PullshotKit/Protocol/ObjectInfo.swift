import Foundation

/// GetObjectInfo가 돌려주는 객체(폴더나 파일) 정보 중 쓰는 칸입니다.
public struct ObjectInfo: Equatable, Sendable {
    public var storageID: UInt32
    public var format: PTP.ObjectFormat
    /// 4GiB를 넘거나 기기가 모를 때는 0xFFFFFFFF입니다.
    public var compressedSize: UInt32
    public var parent: UInt32
    public var filename: String
    /// 표준 날짜 문자열(예: "20261114T211205")입니다. 비어 있을 수 있습니다.
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
        _ = try reader.u16() // ProtectionStatus
        let compressedSize = try reader.u32()
        _ = try reader.u16() // ThumbFormat
        _ = try reader.bytes(24) // ThumbCompressedSize, ThumbPix 너비와 높이, ImagePix 너비와 높이, ImageBitDepth
        let parent = try reader.u32()
        _ = try reader.u16() // AssociationType
        _ = try reader.u32() // AssociationDesc
        _ = try reader.u32() // SequenceNumber
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
