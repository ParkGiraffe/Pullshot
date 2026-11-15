/// USB 엔드포인트 디스크립터 중 쓰는 칸입니다.
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

/// PTP가 쓰는 파이프의 엔드포인트 주소입니다.
public struct PipeAddresses: Equatable, Sendable {
    public var bulkIn: UInt8
    public var bulkOut: UInt8
    public var interruptIn: UInt8?
}

/// still image 인터페이스의 엔드포인트에서 PTP가 쓰는 파이프를 고릅니다.
public enum EndpointSelection {
    /// 주소의 0x80 비트가 서 있으면 기기에서 Mac으로 들어오는 방향입니다.
    public static func pick(_ endpoints: [EndpointDescriptor]) -> PipeAddresses? {
        let isIncoming = { (endpoint: EndpointDescriptor) in endpoint.address & 0x80 != 0 }
        guard let bulkIn = endpoints.first(where: { $0.transferType == .bulk && isIncoming($0) }),
              let bulkOut = endpoints.first(where: { $0.transferType == .bulk && !isIncoming($0) })
        else { return nil }
        let interruptIn = endpoints.first { $0.transferType == .interrupt && isIncoming($0) }
        return PipeAddresses(bulkIn: bulkIn.address, bulkOut: bulkOut.address, interruptIn: interruptIn?.address)
    }
}
