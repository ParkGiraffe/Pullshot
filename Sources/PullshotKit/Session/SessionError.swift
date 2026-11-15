public enum SessionError: Error, Equatable {
    /// 기기가 OK가 아닌 응답을 보냈습니다. 세션은 계속 쓸 수 있습니다.
    case response(PTP.Response, operation: PTP.Operation)
    case unexpectedContainer(kind: UInt16, code: UInt16)
    case transactionMismatch(expected: UInt32, got: UInt32)
    case transport(TransportError)
    /// 앞선 실패로 기기와 주고받기가 어긋나 이 세션을 더 쓸 수 없습니다. 다시 연결해야 합니다.
    case invalidated
    case cancelled
    /// 복구하느라 USB 장치를 다시 붙였습니다. 기기가 다시 나타나면 새로 연결해야 합니다.
    case needsUSBReset
    case destinationExists(String)
    case sizeMismatch(expected: UInt64, actual: UInt64)
}
