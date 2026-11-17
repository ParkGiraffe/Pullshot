import Foundation

public struct CaptureKey: Hashable, Codable, Sendable {
    public var serialNumber: String
    public var gameFolder: String?
    public var filename: String
    public var size: UInt64?

    public init(_ capture: Capture, serialNumber: String) {
        self.serialNumber = serialNumber
        gameFolder = capture.gameFolder
        filename = capture.filename
        size = capture.size
    }
}
