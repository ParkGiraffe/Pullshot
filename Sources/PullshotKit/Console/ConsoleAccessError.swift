public enum ConsoleAccessError: Error, Equatable {
    case heldByAnotherApp(code: UInt32, owner: String?)
    case noStillImageInterface
    case missingEndpoints
    case other(code: UInt32)

    public init(ioReturn: Int, exclusiveOwner: String? = nil) {
        let code = UInt32(truncatingIfNeeded: ioReturn)
        switch code {
        case 0xE000_02C5, 0xE000_02C9:
            let owner = exclusiveOwner?.split(separator: ", ", maxSplits: 1).last.map(String.init)
            self = .heldByAnotherApp(code: code, owner: owner)
        default:
            self = .other(code: code)
        }
    }
}
