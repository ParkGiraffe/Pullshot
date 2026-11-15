/// 기기의 사진 전송 인터페이스를 잡지 못한 이유입니다.
public enum ConsoleAccessError: Error, Equatable {
    /// 미리보기, 이미지 캡처, 사진 앱이나 그 뒤의 `ptpcamerad`가 인터페이스를 잡고 있습니다.
    /// 미리보기가 켜져 있으면 0xE00002C9(kIOReturnInternalError)가 나옵니다(2026-11-08, 스위치 2 펌웨어 23.0.1에서 확인).
    /// `owner`는 인터페이스를 쥔 프로세스 이름입니다(예: "Tethersnap", "ptpcamerad"). 모르면 nil입니다.
    case heldByAnotherApp(code: UInt32, owner: String?)
    case noStillImageInterface
    case missingEndpoints
    case other(code: UInt32)

    /// IOKit 오류 코드는 Int32로 부호가 붙어 올 때가 있어 32비트로 맞춰 비교합니다.
    /// `exclusiveOwner`는 인터페이스의 `UsbExclusiveOwner` 속성("pid 38635, Tethersnap" 꼴)입니다.
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
