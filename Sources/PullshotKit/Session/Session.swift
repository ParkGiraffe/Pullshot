import Foundation

/// 기기와 연 PTP 세션입니다. 한 번에 한 트랜잭션만 주고받으며, 여러 스레드에서 함께 쓰지 않습니다.
public final class Session {
    static let writeTimeout: TimeInterval = 5
    static let commandReadTimeout: TimeInterval = 10
    static let dataReadTimeout: TimeInterval = 30
    static let readLength = 512 * 1024
    static let maxStrayEvents = 16

    let transport: Transport
    let trace: ((String) -> Void)?
    var buffer = PacketBuffer()
    /// 세션 없는 GetDeviceInfo와 OpenSession은 0을 쓰고, 세션 안의 첫 명령은 1부터 셉니다.
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

    /// `parent`가 `PTP.rootParent`면 루트 바로 아래, 폴더 핸들이면 그 폴더 바로 아래 객체입니다.
    public func objectHandles(storage: UInt32, parent: UInt32) throws -> [UInt32] {
        var reader = try ByteReader(transact(.getObjectHandles, [storage, 0, parent]).data)
        return try reader.u32Array()
    }

    public func objectInfo(_ handle: UInt32) throws -> ObjectInfo {
        try ObjectInfo(transact(.getObjectInfo, [handle]).data)
    }

    /// 명령 하나를 주고받고, OK가 아니면 그 응답을 오류로 던집니다.
    func transact(
        _ operation: PTP.Operation,
        _ parameters: [UInt32] = [],
        transactionID: UInt32? = nil
    ) throws -> (data: Data, response: Container) {
        let exchanged = try exchange(operation, parameters, transactionID: transactionID)
        guard exchanged.response.code == PTP.Response.ok.rawValue else {
            throw SessionError.response(PTP.Response(rawValue: exchanged.response.code), operation: operation)
        }
        return exchanged
    }

    /// 응답 코드를 따지지 않고 명령, 데이터, 응답을 주고받습니다. 열기처럼 OK가 아닌 응답도 다뤄야 할 때 씁니다.
    func exchange(
        _ operation: PTP.Operation,
        _ parameters: [UInt32] = [],
        transactionID: UInt32? = nil
    ) throws -> (data: Data, response: Container) {
        let id = try transactionID ?? takeTransactionID()
        return try guarded {
            try send(.command(operation, transactionID: id, parameters: parameters))
            var data = Data()
            var strayEvents = 0
            while true {
                let container = try nextContainer(timeout: Self.commandReadTimeout)
                switch container.kind {
                case .data:
                    try requireTransaction(id, in: container)
                    data.append(container.payload)
                case .response:
                    try requireTransaction(id, in: container)
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

    /// 어긋날 수 있는 일을 감쌉니다. 어떤 실패든 기기와의 순서가 어긋났을 수 있어 세션을 버립니다.
    func guarded<T>(_ body: () throws -> T) throws -> T {
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
        Log.ptp.error("세션을 버립니다: \(String(describing: error), privacy: .public)")
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
            // 0바이트 읽기(ZLP)는 버퍼에 아무것도 더하지 않으므로 다음 읽기로 넘어갑니다.
            try buffer.append(transport.read(maxLength: Self.readLength, timeout: timeout))
        }
    }

    func requireTransaction(_ expected: UInt32, in container: Container) throws {
        guard container.transactionID == expected else {
            throw SessionError.transactionMismatch(expected: expected, got: container.transactionID)
        }
    }

    func unexpected(_ container: Container) -> SessionError {
        .unexpectedContainer(kind: container.kind.rawValue, code: container.code)
    }

    private func takeTransactionID() throws -> UInt32 {
        let id = nextTransactionID
        // 0xFFFFFFFF는 표준이 예약해 두었으므로 그 앞에서 1로 돌아갑니다.
        nextTransactionID = id == 0xFFFF_FFFE ? 1 : id + 1
        return id
    }

    static func hex(_ code: UInt16) -> String {
        String(format: "0x%04X", code)
    }
}
