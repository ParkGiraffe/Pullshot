public struct ConsoleModel: Equatable, Sendable {
    public let vendorID: UInt16
    public let productID: UInt16
    public let name: String
    public let idleProductID: UInt16?
    public let isExperimental: Bool

    public static let switch2 = Self(
        vendorID: 0x057E,
        productID: 0x2061,
        name: "Nintendo Switch 2",
        idleProductID: 0x2060,
        isExperimental: false
    )
    public static let switch1 = Self(
        vendorID: 0x057E,
        productID: 0x201D,
        name: "Nintendo Switch",
        idleProductID: nil,
        isExperimental: true
    )
    public static let all = [switch2, switch1]

    public static func matching(vendorID: UInt16, productID: UInt16) -> Self? {
        all.first { $0.vendorID == vendorID && $0.productID == productID }
    }

    public static func matchingIdle(vendorID: UInt16, productID: UInt16) -> Self? {
        all.first { $0.vendorID == vendorID && $0.idleProductID == productID }
    }
}
