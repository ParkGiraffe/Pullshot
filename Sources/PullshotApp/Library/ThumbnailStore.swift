import AppKit
import ImageIO
import Observation
import PullshotKit
import UniformTypeIdentifiers

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

    /// 미리보기 패널이 원본을 받기 전에 보일 썸네일 파일입니다. 받아 둔 썸네일이 없으면 기기에서 받고, 받지 못하면
    /// nil입니다. 미리보기 폴더 안에 두어 앱을 시작할 때와 끝낼 때 함께 지웁니다.
    func previewFile(for capture: Capture) async -> URL? {
        guard let serialNumber, Capture.isSafeFilename(serialNumber) else { return nil }
        let file = DeviceWorker.previewFolder.appending(path: ".thumbnails").appending(path: serialNumber)
            .appending(path: capture.gameName).appending(path: "\(capture.filename).jpg")
        if FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) {
            return file
        }
        guard let image = await image(for: capture)?.cgImage(forProposedRect: nil, context: nil, hints: nil),
              await Self.writePreview(image, to: file)
        else { return nil }
        return file
    }

    /// 썸네일을 원본 폭(1920)으로 키워 씁니다. 패널은 그림 크기에 맞춰 커지므로, 원본이 와도 패널 크기가 그대로입니다.
    @concurrent private static func writePreview(_ image: CGImage, to file: URL) async -> Bool {
        let width = 1920
        let height = width * image.height / max(image.width, 1)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return false }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        try? FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard let scaled = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(
                  file as CFURL,
                  UTType.jpeg.identifier as CFString,
                  1,
                  nil
              )
        else { return false }
        CGImageDestinationAddImage(destination, scaled, nil)
        return CGImageDestinationFinalize(destination)
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
