import Foundation

/// 컨테이너 앞 12바이트입니다. 길이는 헤더를 포함합니다.
public struct ContainerHeader: Equatable, Sendable {
    public static let size = 12

    public var length: UInt32
    public var kind: PTP.ContainerKind
    public var code: UInt16
    public var transactionID: UInt32
}

public extension ContainerHeader {
    init(_ data: Data) throws {
        var reader = ByteReader(data)
        let length = try reader.u32()
        let rawKind = try reader.u16()
        let code = try reader.u16()
        let transactionID = try reader.u32()
        guard Int(length) >= Self.size else { throw PTPDecodingError.badContainerLength(length) }
        guard let kind = PTP.ContainerKind(rawValue: rawKind)
        else { throw PTPDecodingError.unknownContainerKind(rawKind) }
        self.init(length: length, kind: kind, code: code, transactionID: transactionID)
    }
}

/// 명령, 데이터, 응답, 이벤트 하나입니다.
public struct Container: Equatable, Sendable {
    public var kind: PTP.ContainerKind
    public var code: UInt16
    public var transactionID: UInt32
    public var payload: Data

    public static func command(_ operation: PTP.Operation, transactionID: UInt32, parameters: [UInt32] = []) -> Self {
        precondition(parameters.count <= 5, "PTP 명령 인자는 5개까지입니다")
        var payload = ByteWriter()
        parameters.forEach { payload.u32($0) }
        return Self(kind: .command, code: operation.rawValue, transactionID: transactionID, payload: payload.data)
    }

    public func encoded() -> Data {
        var writer = ByteWriter()
        writer.u32(UInt32(ContainerHeader.size + payload.count))
        writer.u16(kind.rawValue)
        writer.u16(code)
        writer.u32(transactionID)
        writer.bytes(payload)
        return writer.data
    }

    /// 응답 컨테이너의 인자입니다. 4바이트로 나눠떨어지지 않는 꼬리는 버립니다.
    public var parameters: [UInt32] {
        var reader = ByteReader(payload)
        return (0 ..< payload.count / 4).compactMap { _ in try? reader.u32() }
    }
}
