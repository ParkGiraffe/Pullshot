/// Pullshot이 아는 기기입니다. 표시 이름은 호환 기기를 설명하는 데만 씁니다.
public struct ConsoleModel: Equatable, Sendable {
    public let vendorID: UInt16
    public let productID: UInt16
    public let name: String
    /// 실기기로 확인하지 못한 기기입니다. 연결하면 실험적 지원이라고 알립니다.
    public let isExperimental: Bool

    /// PC로 복사 모드의 Nintendo Switch 2입니다.
    public static let switch2 = Self(
        vendorID: 0x057E,
        productID: 0x2061,
        name: "Nintendo Switch 2",
        isExperimental: false
    )
    /// 시스템 버전 11.0 이상의 Nintendo Switch와 Switch Lite입니다. 같은 프로토콜이라고 알려져 있지만 확인하지 못했습니다.
    public static let switch1 = Self(vendorID: 0x057E, productID: 0x201D, name: "Nintendo Switch", isExperimental: true)
    public static let all = [switch2, switch1]

    public static func matching(vendorID: UInt16, productID: UInt16) -> Self? {
        all.first { $0.vendorID == vendorID && $0.productID == productID }
    }
}
