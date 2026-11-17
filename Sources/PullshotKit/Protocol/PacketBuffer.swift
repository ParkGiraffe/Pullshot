import Foundation

public struct PacketBuffer {
    private var bytes = Data()

    public init() {}

    public var isEmpty: Bool {
        bytes.isEmpty
    }

    public mutating func append(_ chunk: Data) {
        bytes.append(chunk)
    }

    public func peekHeader() throws -> ContainerHeader? {
        guard bytes.count >= ContainerHeader.size else { return nil }
        return try ContainerHeader(bytes.prefix(ContainerHeader.size))
    }

    public mutating func removeFirst(upTo count: Int) -> Data {
        let taken = Data(bytes.prefix(count))
        bytes.removeSubrange(bytes.startIndex ..< bytes.startIndex + taken.count)
        return taken
    }

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
