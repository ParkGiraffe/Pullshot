import Foundation

/// 기기가 찍은 사진 한 장이나 영상 하나입니다.
/// `handle`과 `storageID`는 지금 세션에서만 뜻이 있어 저장하지 않습니다(스위치는 세션마다 저장소 ID를 바꿉니다).
public struct Capture: Equatable, Sendable, Identifiable {
    public enum Kind: Sendable {
        case photo
        case video
    }

    public var handle: UInt32
    public var storageID: UInt32
    public var filename: String
    public var size: UInt64?
    public var capturedAt: Date?
    public var kind: Kind
    /// 캡처가 든 앨범 폴더 이름, 곧 게임 이름입니다. 루트에 있거나 폴더 이름을 경로로 쓸 수 없으면 nil입니다.
    public var gameFolder: String?

    public var id: String {
        "\(gameFolder ?? "")/\(filename)"
    }

    /// 경로에 넣어도 받을 폴더 밖을 가리키지 않는 이름인지 봅니다. 기기가 보낸 이름을 그대로 믿지 않습니다.
    public static func isSafeFilename(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/") && !name.contains("\0")
    }
}
