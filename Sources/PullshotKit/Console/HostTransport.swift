import Foundation
import IOKit
import IOUSBHost

public final class HostTransport: Transport {
    private static let stillImage = (interfaceClass: 6, subclass: 1, protocol: 1)

    private let device: io_service_t
    private var interface: IOUSBHostInterface?
    private let bulkIn: IOUSBHostPipe
    private let bulkOut: IOUSBHostPipe
    private let interfaceNumber: UInt16
    private let trace: ((String) -> Void)?

    public init(console: AttachedConsole, trace: ((String) -> Void)? = nil) throws {
        self.trace = trace
        device = IOServiceGetMatchingService(kIOMainPortDefault, IORegistryEntryIDMatching(console.registryID))
        guard device != 0 else { throw ConsoleAccessError.other(code: UInt32(bitPattern: kIOReturnNoDevice)) }
        guard let service = Self.stillImageInterface(of: device) else {
            IOObjectRelease(device)
            throw ConsoleAccessError.noStillImageInterface
        }
        defer { IOObjectRelease(service) }

        let interface: IOUSBHostInterface
        do {
            interface = try IOUSBHostInterface(__ioService: service, options: [], queue: nil, interestHandler: nil)
        } catch {
            IOObjectRelease(device)
            let owner: String? = ConsoleLocator.property("UsbExclusiveOwner", of: service)
            let code = UInt32(truncatingIfNeeded: (error as NSError).code)
            trace?("인터페이스 열기 실패 \(String(format: "0x%08X", code)), 쥔 프로세스: \(owner ?? "모름")")
            throw ConsoleAccessError(ioReturn: (error as NSError).code, exclusiveOwner: owner)
        }
        do {
            guard let pipes = EndpointSelection.pick(Self.endpoints(of: interface)) else {
                throw ConsoleAccessError.missingEndpoints
            }
            bulkIn = try interface.copyPipe(withAddress: Int(pipes.bulkIn))
            bulkOut = try interface.copyPipe(withAddress: Int(pipes.bulkOut))
        } catch {
            interface.destroy()
            IOObjectRelease(device)
            throw error as? ConsoleAccessError ?? ConsoleAccessError(ioReturn: (error as NSError).code)
        }
        interfaceNumber = UInt16(interface.interfaceDescriptor.pointee.bInterfaceNumber)
        self.interface = interface
        Log.usb.notice("\(console.model.name, privacy: .public) 인터페이스를 잡았습니다")
    }

    deinit {
        close()
        IOObjectRelease(device)
    }

    public func write(_ data: Data, timeout: TimeInterval) throws {
        trace?("bulk-out \(data.count)B")
        try transfer(on: bulkOut, NSMutableData(data: data), timeout: timeout)
    }

    public func read(maxLength: Int, timeout: TimeInterval) throws -> Data {
        guard let buffer = NSMutableData(length: maxLength)
        else { throw TransportError.io(code: UInt32(bitPattern: kIOReturnNoMemory)) }
        let received = try transfer(on: bulkIn, buffer, timeout: timeout)
        trace?("bulk-in \(maxLength) → \(received)B")
        return Data(bytes: buffer.bytes, count: received)
    }

    public func resetPTPDevice() throws {
        guard let interface else { throw TransportError.disconnected }
        trace?("PTP 장치 리셋")
        let request = IOUSBDeviceRequest(
            bmRequestType: 0x21,
            bRequest: 0x66,
            wValue: 0,
            wIndex: interfaceNumber,
            wLength: 0
        )
        var sent: UInt = 0
        do {
            try interface.__send(request, data: nil, bytesTransferred: &sent, completionTimeout: Session.writeTimeout)
        } catch {
            trace?("PTP 장치 리셋 실패 \(String(format: "0x%08X", UInt32(truncatingIfNeeded: (error as NSError).code)))")
            throw TransportError(ioReturn: (error as NSError).code)
        }
    }

    public func resetUSBDevice() throws {
        trace?("USB 장치 리셋")
        close()
        do {
            let host = try IOUSBHostDevice(__ioService: device, options: [], queue: nil, interestHandler: nil)
            defer { host.destroy() }
            try host.reset()
        } catch {
            throw TransportError(ioReturn: (error as NSError).code)
        }
    }

    public func close() {
        interface?.destroy()
        interface = nil
    }

    @discardableResult
    private func transfer(on pipe: IOUSBHostPipe, _ buffer: NSMutableData, timeout: TimeInterval) throws -> Int {
        guard interface != nil else { throw TransportError.disconnected }
        var transferred: UInt = 0
        do {
            try pipe.__sendIORequest(with: buffer, bytesTransferred: &transferred, completionTimeout: timeout)
            return Int(transferred)
        } catch {
            let transportError = TransportError(ioReturn: (error as NSError).code)
            trace?("오류 \(String(format: "0x%08X", UInt32(truncatingIfNeeded: (error as NSError).code)))")
            if transportError == .stalled {
                try? pipe.clearStall()
            }
            throw transportError
        }
    }

    private static func stillImageInterface(of device: io_service_t) -> io_service_t? {
        var children: io_iterator_t = 0
        guard IORegistryEntryGetChildIterator(device, kIOServicePlane, &children) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(children) }
        while case let child = IOIteratorNext(children), child != 0 {
            let numbers = ["bInterfaceClass", "bInterfaceSubClass", "bInterfaceProtocol"].map {
                (ConsoleLocator.property($0, of: child) as NSNumber?)?.intValue
            }
            if numbers == [stillImage.interfaceClass, stillImage.subclass, stillImage.protocol] {
                return child
            }
            IOObjectRelease(child)
        }
        return nil
    }

    private static func endpoints(of interface: IOUSBHostInterface) -> [EndpointDescriptor] {
        let configuration = interface.configurationDescriptor
        let interfaceDescriptor = interface.interfaceDescriptor
        var endpoints: [EndpointDescriptor] = []
        var current = IOUSBGetNextEndpointDescriptor(configuration, interfaceDescriptor, nil)
        while let endpoint = current {
            let types: [EndpointDescriptor.TransferType] = [.control, .isochronous, .bulk, .interrupt]
            endpoints.append(EndpointDescriptor(
                address: endpoint.pointee.bEndpointAddress,
                transferType: types[Int(endpoint.pointee.bmAttributes & 0x03)],
                maxPacketSize: UInt16(littleEndian: endpoint.pointee.wMaxPacketSize)
            ))
            current = IOUSBGetNextEndpointDescriptor(
                configuration,
                interfaceDescriptor,
                UnsafeRawPointer(endpoint).assumingMemoryBound(to: IOUSBDescriptorHeader.self)
            )
        }
        return endpoints
    }
}

extension TransportError {
    init(ioReturn: Int) {
        let code = UInt32(truncatingIfNeeded: ioReturn)
        switch code {
        case 0xE000_5000:
            self = .stalled
        case 0xE000_02D6:
            self = .timedOut
        case 0xE000_02C0, 0xE000_02D7, 0xE000_02D9, 0xE000_02EB, 0xE000_02ED:
            self = .disconnected
        default:
            self = .io(code: code)
        }
    }
}
