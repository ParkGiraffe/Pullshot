import Foundation
@testable import PullshotKit

/// 스위치 2를 흉내 낸 DeviceInfo 데이터셋입니다.
func deviceInfoFixture(
    model: String = "Nintendo Switch 2",
    serial: String = "TEST0001",
    version: String = "23.0.1",
    operations: [UInt16] = PTP.Operation.baseline.map(\.rawValue)
) -> Data {
    var writer = ByteWriter()
    writer.u16(100)
    writer.u32(0)
    writer.u16(0)
    writer.string("")
    writer.u16(0)
    writer.u16Array(operations)
    writer.u16Array([])
    writer.u16Array([])
    writer.u16Array([])
    writer.u16Array([PTP.ObjectFormat.exifJPEG.rawValue])
    writer.string("Nintendo")
    writer.string(model)
    writer.string(version)
    writer.string(serial)
    return writer.data
}

func storageInfoFixture(maxCapacity: UInt64 = 64_000_000_000) -> Data {
    var writer = ByteWriter()
    writer.u16(0x0004)
    writer.u16(0x0002)
    writer.u16(0x0001)
    writer.u64(maxCapacity)
    writer.u64(maxCapacity)
    writer.u32(0xFFFF_FFFF)
    writer.string("")
    writer.string("")
    return writer.data
}

func objectInfoFixture(
    filename: String,
    format: PTP.ObjectFormat = .exifJPEG,
    size: UInt32 = 1000,
    parent: UInt32 = 0,
    storageID: UInt32 = 0x0001_0001,
    captureDate: String = ""
) -> Data {
    var writer = ByteWriter()
    writer.u32(storageID)
    writer.u16(format.rawValue)
    writer.u16(0)
    writer.u32(size)
    writer.u16(PTP.ObjectFormat.exifJPEG.rawValue)
    for _ in 0 ..< 6 {
        writer.u32(0)
    }
    writer.u32(parent)
    writer.u16(format == .association ? 0x0001 : 0)
    writer.u32(0)
    writer.u32(0)
    writer.string(filename)
    writer.string(captureDate)
    writer.string("")
    writer.string("")
    return writer.data
}
