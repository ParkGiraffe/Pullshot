/// 기기가 보낸 바이트를 PTP 구조로 풀지 못한 이유입니다.
public enum PTPDecodingError: Error, Equatable {
    case truncated(needed: Int, available: Int)
    case badString
    case badContainerLength(UInt32)
    case unknownContainerKind(UInt16)
}
