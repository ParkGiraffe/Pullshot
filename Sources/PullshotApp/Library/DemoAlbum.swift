import Foundation
import PullshotKit

/// `-demoAlbum YES`로 열 때 기기 대신 보이는 앨범입니다. 스위치가 없는 원격 맥에서 화면을 확인하려는 것입니다.
enum DemoAlbum {
    static let console = AttachedConsole(model: .switch2, registryID: 0, locationID: nil, serialNumber: nil)
    /// 펌웨어는 실기기 기록(`docs/hardware-notes.md`)의 값입니다.
    static let info = DeviceInfo(
        standardVersion: 100,
        vendorExtensionID: 0,
        operationsSupported: [],
        manufacturer: "Nintendo",
        model: "Nintendo Switch 2",
        deviceVersion: "23.5.0",
        serialNumber: "DEMO"
    )

    /// 사이드바에서 두 줄을 넘는 이름이 말줄임되는지 보려고 셋째 게임 이름을 길게 둡니다.
    private static let games = [
        "젤다무쌍 봉인전기",
        "마리오 카트 월드",
        "젤다의 전설 티어스 오브 더 킹덤 Nintendo Switch 2 Edition",
    ]

    /// 게임 세 개를 번갈아 사흘마다 한 번 플레이해 세 장씩 찍은 60개를 최근 것부터 돌려줍니다.
    /// 다섯 번째마다 영상이라 사진과 영상이 섞이고, 최근 두 달에 흩어집니다.
    static func captures(now: Date) -> [Capture] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMddHHmmss"
        return (0 ..< 60).map { number in
            let play = number / 3
            // 플레이마다 시작 시각을 한 시간씩 바꾸고, 한 플레이 안에서는 7분 간격으로 찍습니다.
            let secondsAgo = play * 3 * 86400 + play % 4 * 3600 + number % 3 * 420
            let capturedAt = now.addingTimeInterval(-Double(secondsAgo))
            let isVideo = number % 5 == 4
            return Capture(
                handle: UInt32(number + 1),
                storageID: 0x0001_0001,
                filename: "\(formatter.string(from: capturedAt))00_s.\(isVideo ? "mp4" : "jpg")",
                size: isVideo ? 18_000_000 : 420_000,
                capturedAt: capturedAt,
                kind: isVideo ? .video : .photo,
                gameFolder: games[play % games.count]
            )
        }
    }
}
