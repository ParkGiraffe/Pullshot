import Foundation
import IOKit
import IOUSBHost

public struct AttachedConsole: Equatable, Sendable {
    public var model: ConsoleModel
    public var registryID: UInt64
    public var locationID: UInt32?
    public var serialNumber: String?

    public init(model: ConsoleModel, registryID: UInt64, locationID: UInt32?, serialNumber: String?) {
        self.model = model
        self.registryID = registryID
        self.locationID = locationID
        self.serialNumber = serialNumber
    }
}

public enum ConsoleLocator {
    public static func attached() -> [AttachedConsole] {
        devices(productIDs: ConsoleModel.all.map(\.productID), console(at:))
    }

    public static func idle() -> [ConsoleModel] {
        devices(productIDs: ConsoleModel.all.compactMap(\.idleProductID)) { service in
            guard let vendorID: NSNumber = property("idVendor", of: service),
                  let productID: NSNumber = property("idProduct", of: service)
            else { return nil }
            return ConsoleModel.matchingIdle(vendorID: vendorID.uint16Value, productID: productID.uint16Value)
        }
    }

    static func matchingDictionary(productIDs: [UInt16]) -> CFMutableDictionary {
        IOUSBHostDevice.__createMatchingDictionary(
            withVendorID: NSNumber(value: ConsoleModel.switch2.vendorID),
            productID: nil,
            bcdDevice: nil,
            deviceClass: nil,
            deviceSubclass: nil,
            deviceProtocol: nil,
            speed: nil,
            productIDArray: productIDs.map { NSNumber(value: $0) }
        ).takeRetainedValue()
    }

    private static func devices<T>(productIDs: [UInt16], _ transform: (io_service_t) -> T?) -> [T] {
        let matching = matchingDictionary(productIDs: productIDs)
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }

        var found: [T] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            if let device = transform(service) {
                found.append(device)
            }
        }
        return found
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
