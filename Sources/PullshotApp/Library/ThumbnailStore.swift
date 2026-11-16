import AppKit
import ImageIO
import Observation
import PullshotKit

/// 격자 칸이 쓰는 썸네일 창구입니다. 메모리, 디스크, 기기 순으로 찾고 기기에서 받은 것은 디스크에 둡니다.
@MainActor @Observable
final class ThumbnailStore {
    /// 바뀌면 다른 기기의 그림이 섞이지 않도록 메모리 캐시를 비웁니다.
    var serialNumber: String? {
        didSet {
            if serialNumber != oldValue {
                memory.removeAllObjects()
            }
        }
    }

    var isDemo = false

    @ObservationIgnored private let memory = NSCache<NSString, NSImage>()
    @ObservationIgnored private let worker: DeviceWorker
    @ObservationIgnored private let cache: ThumbnailCache

    init(worker: DeviceWorker, cache: ThumbnailCache = ThumbnailCache()) {
        self.worker = worker
        self.cache = cache
    }

    /// 실패와 취소는 nil입니다. 칸이 화면을 벗어나 작업이 취소되면 기기에 보내지 않습니다.
    /// 기기를 바꾼 뒤 앞 기기에서 시작한 요청이 늦게 끝나면 같은 id의 다른 기기 캡처에 섞이므로 버립니다.
    func image(for capture: Capture) async -> NSImage? {
        if let image = memory.object(forKey: capture.id as NSString) {
            return image
        }
        let requestedSerial = serialNumber
        let image = if isDemo {
            Self.demoImage(for: capture)
        } else if let requestedSerial {
            await load(capture, serialNumber: requestedSerial)
        } else {
            nil as NSImage?
        }
        guard let image, serialNumber == requestedSerial else { return nil }
        memory.setObject(image, forKey: capture.id as NSString)
        return image
    }

    /// 디스크 읽기, 디코딩, 디스크 쓰기는 메인 액터 밖에서 하고, 다 만든 그림만 돌려받습니다.
    private func load(_ capture: Capture, serialNumber: String) async -> NSImage? {
        let key = CaptureKey(capture, serialNumber: serialNumber)
        let cache = cache
        if let decoded = await Self.cachedImage(for: key, in: cache) {
            return NSImage(cgImage: decoded, size: .zero)
        }
        guard let data = try? await worker.thumbnail(of: capture), self.serialNumber == serialNumber,
              let decoded = await Self.decodeAndStore(data, for: key, in: cache) else { return nil }
        return NSImage(cgImage: decoded, size: .zero)
    }

    @concurrent private static func cachedImage(for key: CaptureKey, in cache: ThumbnailCache) async -> CGImage? {
        cache.data(for: key).flatMap(decode)
    }

    @concurrent private static func decodeAndStore(
        _ data: Data,
        for key: CaptureKey,
        in cache: ThumbnailCache
    ) async -> CGImage? {
        guard let image = decode(data) else { return nil }
        cache.store(data, for: key)
        return image
    }

    /// 스크롤 중에 그리다 끊기지 않도록 만들 때 미리 풀어 둡니다.
    private nonisolated static func decode(_ data: Data) -> CGImage? {
        CGImageSourceCreateWithData(data as CFData, nil).flatMap {
            CGImageSourceCreateImageAtIndex($0, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        }
    }

    /// 파일 이름으로 색상을 정한 단색 그림입니다. 파일 이름이 같으면 색도 같습니다.
    private static func demoImage(for capture: Capture) -> NSImage {
        let hue = Double(capture.filename.unicodeScalars.reduce(0) { ($0 * 31 + Int($1.value)) % 360 }) / 360
        return NSImage(size: NSSize(width: 160, height: 90), flipped: false) { rect in
            NSColor(hue: hue, saturation: 0.45, brightness: 0.85, alpha: 1).setFill()
            rect.fill()
            return true
        }
    }
}
