import Foundation

/// GetDeviceInfo가 돌려주는 기기 정보 중 쓰는 칸입니다.
public struct DeviceInfo: Equatable, Sendable {
    public var standardVersion: UInt16
    public var vendorExtensionID: UInt32
    public var operationsSupported: [UInt16]
    public var manufacturer: String
    public var model: String
    /// 스위치는 펌웨어 버전(예: "23.0.1")을 담습니다.
    public var deviceVersion: String
    public var serialNumber: String

    public init(
        standardVersion: UInt16,
        vendorExtensionID: UInt32,
        operationsSupported: [UInt16],
        manufacturer: String,
        model: String,
        deviceVersion: String,
        serialNumber: String
    ) {
        self.standardVersion = standardVersion
        self.vendorExtensionID = vendorExtensionID
        self.operationsSupported = operationsSupported
        self.manufacturer = manufacturer
        self.model = model
        self.deviceVersion = deviceVersion
        self.serialNumber = serialNumber
    }
}

public extension DeviceInfo {
    init(_ data: Data) throws {
        var reader = ByteReader(data)
        let standardVersion = try reader.u16()
        let vendorExtensionID = try reader.u32()
        _ = try reader.u16() // VendorExtensionVersion
        _ = try reader.string() // VendorExtensionDesc
        _ = try reader.u16() // FunctionalMode
        let operationsSupported = try reader.u16Array()
        _ = try reader.u16Array() // EventsSupported
        _ = try reader.u16Array() // DevicePropertiesSupported
        _ = try reader.u16Array() // CaptureFormats
        _ = try reader.u16Array() // ImageFormats
        try self.init(
            standardVersion: standardVersion,
            vendorExtensionID: vendorExtensionID,
            operationsSupported: operationsSupported,
            manufacturer: reader.string(),
            model: reader.string(),
            deviceVersion: reader.string(),
            serialNumber: reader.string()
        )
    }
}
