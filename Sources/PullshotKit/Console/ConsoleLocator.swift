import Foundation
import IOKit
import IOUSBHost

/// 지금 꽂혀 있는 스위치 하나입니다.
public struct AttachedConsole: Equatable, Sendable {
    public var model: ConsoleModel
    /// IOKit 레지스트리 ID입니다. 다시 꽂으면 바뀝니다.
    public var registryID: UInt64
    public var locationID: UInt32?
    public var serialNumber: String?
}

/// USB에 꽂힌 스위치를 찾습니다.
public enum ConsoleLocator {
    public static func attached() -> [AttachedConsole] {
        let matching = IOUSBHostDevice.__createMatchingDictionary(
            withVendorID: NSNumber(value: ConsoleModel.switch2.vendorID),
            productID: nil,
            bcdDevice: nil,
            deviceClass: nil,
            deviceSubclass: nil,
            deviceProtocol: nil,
            speed: nil,
            productIDArray: nil
        ).takeRetainedValue()
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }

        var consoles: [AttachedConsole] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            if let console = console(at: service) {
                consoles.append(console)
            }
        }
        return consoles
    }

    static func console(at service: io_service_t) -> AttachedConsole? {
        guard let vendorID: NSNumber = property("idVendor", of: service),
              let productID: NSNumber = property("idProduct", of: service),
              let model = ConsoleModel.matching(vendorID: vendorID.uint16Value, productID: productID.uint16Value)
        else { return nil }
        var registryID: UInt64 = 0
        IORegistryEntryGetRegistryEntryID(service, &registryID)
        let locationID: NSNumber? = property("locationID", of: service)
        return AttachedConsole(
            model: model,
            registryID: registryID,
            locationID: locationID?.uint32Value,
            serialNumber: property("USB Serial Number", of: service)
        )
    }

    static func property<T>(_ key: String, of service: io_registry_entry_t) -> T? {
        IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? T
    }
}
