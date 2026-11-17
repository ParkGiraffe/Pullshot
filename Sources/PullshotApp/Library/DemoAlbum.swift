import Foundation
import PullshotKit

enum DemoAlbum {
    static let console = AttachedConsole(model: .switch2, registryID: 0, locationID: nil, serialNumber: nil)
    static let info = DeviceInfo(
        standardVersion: 100,
        vendorExtensionID: 0,
        operationsSupported: [],
        manufacturer: "Nintendo",
        model: "Nintendo Switch 2",
        deviceVersion: "23.5.0",
        serialNumber: "DEMO"
    )

    private static let games = [
        "젤다무쌍 봉인전기",
        "마리오 카트 월드",
        "젤다의 전설 티어스 오브 더 킹덤 Nintendo Switch 2 Edition",
    ]

    static func captures(now: Date) -> [Capture] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMddHHmmss"
        return (0 ..< 60).map { number in
            let play = number / 3
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
