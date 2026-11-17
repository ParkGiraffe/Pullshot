import Foundation

public protocol Transport: AnyObject {
    func write(_ data: Data, timeout: TimeInterval) throws
    func read(maxLength: Int, timeout: TimeInterval) throws -> Data
    func resetPTPDevice() throws
    func resetUSBDevice() throws
    func close()
}

public enum TransportError: Error, Equatable {
    case timedOut
    case disconnected
    case stalled
    case io(code: UInt32)
}
