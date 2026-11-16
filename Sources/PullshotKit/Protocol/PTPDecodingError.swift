public enum PTPDecodingError: Error, Equatable {
    case truncated(needed: Int, available: Int)
    case badString
    case badContainerLength(UInt32)
    case unknownContainerKind(UInt16)
}
