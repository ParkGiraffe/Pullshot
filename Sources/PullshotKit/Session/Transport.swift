import Foundation

/// 기기와 바이트를 주고받는 통로입니다. 실제 USB, 테스트용 가짜, 기록과 재생이 이 자리에 들어갑니다.
public protocol Transport: AnyObject {
    /// 컨테이너 하나를 통째로 보냅니다.
    func write(_ data: Data, timeout: TimeInterval) throws
    /// 한 번 읽어 최대 `maxLength`바이트를 돌려줍니다. 0바이트(ZLP)일 수도 있습니다.
    func read(maxLength: Int, timeout: TimeInterval) throws -> Data
    /// PTP 클래스 요청 Device Reset(0x66)입니다.
    func resetPTPDevice() throws
    /// USB 장치를 다시 붙입니다. 기기가 새로 나타나므로 이 전송은 더 쓸 수 없습니다.
    func resetUSBDevice() throws
    func close()
}

public enum TransportError: Error, Equatable {
    case timedOut
    case disconnected
    case stalled
    case io(code: UInt32)
}
