import Foundation

/// GetStorageInfo가 돌려주는 저장소 정보 중 쓰는 칸입니다.
public struct StorageInfo: Equatable, Sendable {
    public var storageType: UInt16
    /// 스위치는 용량을 모두 1인 비트로 보고해서 알 수 없음(nil)으로 둡니다.
    public var maxCapacity: UInt64?
    public var freeSpace: UInt64?
    public var storageDescription: String
    public var volumeLabel: String
}

public extension StorageInfo {
    init(_ data: Data) throws {
        var reader = ByteReader(data)
        let storageType = try reader.u16()
        _ = try reader.u16() // FilesystemType
        _ = try reader.u16() // AccessCapability
        let maxCapacity = try reader.u64()
        let freeSpace = try reader.u64()
        _ = try reader.u32() // FreeSpaceInImages
        try self.init(
            storageType: storageType,
            maxCapacity: Self.known(maxCapacity),
            freeSpace: Self.known(freeSpace),
            storageDescription: reader.string(),
            volumeLabel: reader.string()
        )
    }

    private static func known(_ bytes: UInt64) -> UInt64? {
        bytes == .max ? nil : bytes
    }
}
