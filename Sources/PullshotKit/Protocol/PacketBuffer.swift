import Foundation

/// USB에서 받은 조각을 쌓아 두고 컨테이너 단위로 꺼냅니다.
/// 컨테이너 하나가 여러 조각으로 오기도 하고, 한 조각에 여러 컨테이너가 붙어 오기도 합니다.
public struct PacketBuffer {
    private var bytes = Data()

    public init() {}

    public var count: Int {
        bytes.count
    }

    public var isEmpty: Bool {
        bytes.isEmpty
    }

    public mutating func append(_ chunk: Data) {
        bytes.append(chunk)
    }

    /// 헤더가 다 쌓였으면 읽고, 아니면 nil입니다. 버퍼는 그대로 둡니다.
    public func peekHeader() throws -> ContainerHeader? {
        guard bytes.count >= ContainerHeader.size else { return nil }
        return try ContainerHeader(bytes.prefix(ContainerHeader.size))
    }

    /// 앞에서 최대 `count`바이트를 덜어 냅니다. 큰 데이터를 파일로 흘려 쓸 때 씁니다.
    public mutating func removeFirst(upTo count: Int) -> Data {
        let taken = Data(bytes.prefix(count))
        bytes.removeFirst(taken.count)
        return taken
    }

    /// 컨테이너 전체가 쌓였을 때만 꺼내고, 아니면 nil입니다.
    public mutating func nextContainer() throws -> Container? {
        guard let header = try peekHeader(), bytes.count >= Int(header.length) else { return nil }
        let whole = removeFirst(upTo: Int(header.length))
        return Container(
            kind: header.kind,
            code: header.code,
            transactionID: header.transactionID,
            payload: Data(whole.dropFirst(ContainerHeader.size))
        )
    }
}
