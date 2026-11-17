import Foundation

public final class Session {
    static let writeTimeout: TimeInterval = 5
    static let commandReadTimeout: TimeInterval = 10
    static let dataReadTimeout: TimeInterval = 30
    static let readLength = 512 * 1024
    static let maxStrayEvents = 16
    static let maxEmptyReads = 64

    let transport: Transport
    let trace: ((String) -> Void)?
    var buffer = PacketBuffer()
    private var consecutiveEmptyReads = 0
    var nextTransactionID: UInt32 = 0
    public internal(set) var isOpen = false
    public private(set) var isValid = true

    public init(transport: Transport, trace: ((String) -> Void)? = nil) {
        self.transport = transport
        self.trace = trace
    }

    static func openedForTesting(transport: Transport) -> Session {
        let session = Session(transport: transport)
        session.isOpen = true
        session.nextTransactionID = 1
        return session
    }

    public func storageIDs() throws -> [UInt32] {
        var reader = try ByteReader(transact(.getStorageIDs).data)
        return try reader.u32Array()
    }

    public func storageInfo(_ storage: UInt32) throws -> StorageInfo {
        try StorageInfo(transact(.getStorageInfo, [storage]).data)
    }

    public func objectHandles(storage: UInt32, parent: UInt32) throws -> [UInt32] {
        var reader = try ByteReader(transact(.getObjectHandles, [storage, 0, parent]).data)
        return try reader.u32Array()
    }

    public func objectInfo(_ handle: UInt32) throws -> ObjectInfo {
        try ObjectInfo(transact(.getObjectInfo, [handle]).data)
    }

    func transact(_ operation: PTP.Operation, _ parameters: [UInt32] = []) throws -> (data: Data, response: Container) {
        let reply = try exchange(operation, parameters)
        guard reply.response.code == PTP.Response.ok.rawValue else {
            throw SessionError.response(PTP.Response(rawValue: reply.response.code), operation: operation)
        }
        return reply
    }

    func exchange(
        _ operation: PTP.Operation,
        _ parameters: [UInt32] = [],
        transactionID: UInt32? = nil
    ) throws -> (data: Data, response: Container) {
        try invalidatingOnFailure {
            let id = transactionID ?? takeTransactionID()
            try send(.command(operation, transactionID: id, parameters: parameters))
            var data = Data()
            var strayEvents = 0
            while true {
                let container = try nextContainer(timeout: Self.commandReadTimeout)
                switch container.kind {
                case .data:
                    try requireTransaction(id, container.transactionID)
                    data.append(container.payload)
                case .response:
                    try requireTransaction(id, container.transactionID)
                    return (data, container)
                case .event:
                    strayEvents += 1
                    guard strayEvents <= Self.maxStrayEvents else { throw unexpected(container) }
                case .command:
                    throw unexpected(container)
                }
            }
        }
    }

    func invalidatingOnFailure<T>(_ body: () throws -> T) throws -> T {
        guard isValid else { throw SessionError.invalidated }
        do {
            return try body()
        } catch {
            invalidate(because: error)
            if let transportError = error as? TransportError {
                throw SessionError.transport(transportError)
            }
            throw error
        }
    }

    func invalidate(because error: Error) {
        isValid = false
        Log.ptp.error("세션을 버립니다: \(String(describing: error), privacy: .private)")
    }

    func send(_ container: Container) throws {
        trace?("→ \(Self.hex(container.code)) tid \(container.transactionID)")
        try transport.write(container.encoded(), timeout: Self.writeTimeout)
    }

    func nextContainer(timeout: TimeInterval) throws -> Container {
        while true {
            if let container = try buffer.nextContainer() {
                trace?(container.kind == .data
                    ? "← data \(container.payload.count)B"
                    : "← \(Self.hex(container.code)) tid \(container.transactionID)")
                return container
            }
            try fill(timeout: timeout)
        }
    }

    func fill(timeout: TimeInterval) throws {
        let chunk = try transport.read(maxLength: Self.readLength, timeout: timeout)
        consecutiveEmptyReads = chunk.isEmpty ? consecutiveEmptyReads + 1 : 0
        guard consecutiveEmptyReads <= Self.maxEmptyReads else { throw TransportError.timedOut }
        buffer.append(chunk)
    }

    func requireTransaction(_ expected: UInt32, _ actual: UInt32) throws {
        guard actual == expected else { throw SessionError.transactionMismatch(expected: expected, got: actual) }
    }

    func unexpected(_ container: Container) -> SessionError {
        .unexpectedContainer(kind: container.kind.rawValue, code: container.code)
    }

    func takeTransactionID() -> UInt32 {
        let id = nextTransactionID
        nextTransactionID = id == 0xFFFF_FFFE ? 1 : id + 1
        return id
    }

    static func hex(_ code: UInt16) -> String {
        String(format: "0x%04X", code)
    }
}
