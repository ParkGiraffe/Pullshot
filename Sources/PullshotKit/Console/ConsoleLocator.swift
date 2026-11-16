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

    public init(model: ConsoleModel, registryID: UInt64, locationID: UInt32?, serialNumber: String?) {
        self.model = model
        self.registryID = registryID
        self.locationID = locationID
        self.serialNumber = serialNumber
    }
}

/// USB에 꽂힌 스위치를 찾습니다.
public enum ConsoleLocator {
    /// PC로 복사 모드로 꽂혀 있는 스위치입니다.
    public static func attached() -> [AttachedConsole] {
        devices(productIDs: ConsoleModel.all.map(\.productID), console(at:))
    }

    /// 꽂혀 있지만 PC로 복사 모드가 아닌 스위치입니다. 모드를 켜라고 안내할 때 씁니다.
    public static func idle() -> [ConsoleModel] {
        devices(productIDs: ConsoleModel.all.compactMap(\.idleProductID)) { service in
            guard let vendorID: NSNumber = property("idVendor", of: service),
                  let productID: NSNumber = property("idProduct", of: service)
            else { return nil }
            return ConsoleModel.matchingIdle(vendorID: vendorID.uint16Value, productID: productID.uint16Value)
        }
    }

    /// 스위치를 찾는 IOKit 사전입니다. 찾기와 알림 걸기가 사전의 참조 하나를 가져가므로 쓸 때마다 새로 만듭니다.
    static func matchingDictionary(productIDs: [UInt16]) -> CFMutableDictionary {
        // 제조사 ID만 주면 IOKit이 아무 기기와도 맞추지 않습니다(2026-11-15, 스위치 2 펌웨어 23.5.0에서 확인).
        // 제품 ID 목록을 함께 줍니다.
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
