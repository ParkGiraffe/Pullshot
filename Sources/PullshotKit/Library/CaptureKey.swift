import Foundation

/// 옮긴 기록의 열쇠입니다(설계 6.3). 핸들과 저장소 ID는 세션마다 바뀌어 쓰지 않습니다.
/// 일련번호는 세션과 USB 리셋을 넘어 같아(2026-11-15, 펌웨어 23.5.0) 기기를 가르는 데 씁니다.
/// 게임 폴더는 화면 이름(`gameName`)이 아니라 기기가 보낸 값 그대로라, 스위치의 "기타" 폴더와 루트 캡처가 섞이지 않습니다.
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
