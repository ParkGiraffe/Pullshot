import Foundation
import IOKit
import IOUSBHost

/// IOUSBHost로 스위치의 still image 인터페이스(class 6, subclass 1, protocol 1)를 잡고 벌크 파이프로 주고받습니다.
/// 드라이버나 커널 확장 없이 사용자 공간에서 동작합니다.
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

    /// PTP 클래스 요청 Device Reset(bRequest 0x66)을 인터페이스에 보냅니다.
    public func resetPTPDevice() throws {
        guard let interface else { throw TransportError.disconnected }
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
            throw TransportError(ioReturn: (error as NSError).code)
        }
    }

    /// 인터페이스를 놓고 USB 장치를 다시 붙입니다. 기기가 다시 나타나면 새 전송을 열어야 합니다.
    public func resetUSBDevice() throws {
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

    /// 인터페이스의 엔드포인트 디스크립터를 차례로 읽습니다. 마지막(nil)에서 반드시 멈춥니다.
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
    /// IOKit과 IOUSBHost 오류 코드를 전송 오류로 바꿉니다. 코드는 Int32로 부호가 붙어 올 때가 있어 32비트로 맞춥니다.
    init(ioReturn: Int) {
        let code = UInt32(truncatingIfNeeded: ioReturn)
        switch code {
        case 0xE000_5000: // kUSBHostReturnPipeStalled
            self = .stalled
        case 0xE000_02D6: // kIOReturnTimeout
            self = .timedOut
        case 0xE000_02C0, 0xE000_02D7, 0xE000_02D9, 0xE000_02EB, 0xE000_02ED:
            // NoDevice, Offline, NotAttached, Aborted, NotResponding: 케이블을 뽑았거나 기기가 PC로 복사 모드를 나갔습니다.
            self = .disconnected
        default:
            self = .io(code: code)
        }
    }
}
