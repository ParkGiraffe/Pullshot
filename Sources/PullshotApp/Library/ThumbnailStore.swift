import AppKit
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
    func image(for capture: Capture) async -> NSImage? {
        if let image = memory.object(forKey: capture.id as NSString) {
            return image
        }
        guard let image = isDemo ? Self.demoImage(for: capture) : await load(capture) else { return nil }
        memory.setObject(image, forKey: capture.id as NSString)
        return image
    }

    private func load(_ capture: Capture) async -> NSImage? {
        guard let serialNumber else { return nil }
        let key = CaptureKey(capture, serialNumber: serialNumber)
        if let data = cache.data(for: key), let image = NSImage(data: data) {
            return image
        }
        guard let data = try? await worker.thumbnail(of: capture), let image = NSImage(data: data) else { return nil }
        cache.store(data, for: key)
        return image
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
