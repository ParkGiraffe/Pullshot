public enum SessionError: Error, Equatable {
    case response(PTP.Response, operation: PTP.Operation)
    case unexpectedContainer(kind: UInt16, code: UInt16)
    case transactionMismatch(expected: UInt32, got: UInt32)
    case transport(TransportError)
    case invalidated
    case cancelled
    case needsUSBReset
    case destinationExists(String)
    case sizeMismatch(expected: UInt64, actual: UInt64)
}
