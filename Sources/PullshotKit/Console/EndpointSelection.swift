public struct EndpointDescriptor: Equatable, Sendable {
    public enum TransferType: Sendable {
        case control
        case isochronous
        case bulk
        case interrupt
    }

    public var address: UInt8
    public var transferType: TransferType
    public var maxPacketSize: UInt16
}

public struct PipeAddresses: Equatable, Sendable {
    public var bulkIn: UInt8
    public var bulkOut: UInt8
    public var interruptIn: UInt8?
}

public enum EndpointSelection {
    public static func pick(_ endpoints: [EndpointDescriptor]) -> PipeAddresses? {
        let isIncoming = { (endpoint: EndpointDescriptor) in endpoint.address & 0x80 != 0 }
        guard let bulkIn = endpoints.first(where: { $0.transferType == .bulk && isIncoming($0) }),
              let bulkOut = endpoints.first(where: { $0.transferType == .bulk && !isIncoming($0) })
        else { return nil }
        let interruptIn = endpoints.first { $0.transferType == .interrupt && isIncoming($0) }
        return PipeAddresses(bulkIn: bulkIn.address, bulkOut: bulkOut.address, interruptIn: interruptIn?.address)
    }
}
