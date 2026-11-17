import AppKit
import ImageIO
import Observation
import PullshotKit
import UniformTypeIdentifiers

@MainActor @Observable
final class ThumbnailStore {
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

    private nonisolated static func decode(_ data: Data) -> CGImage? {
        CGImageSourceCreateWithData(data as CFData, nil).flatMap {
            CGImageSourceCreateImageAtIndex($0, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        }
    }

    private static func demoImage(for capture: Capture) -> NSImage {
        let hue = Double(capture.filename.unicodeScalars.reduce(0) { ($0 * 31 + Int($1.value)) % 360 }) / 360
        return NSImage(size: NSSize(width: 160, height: 90), flipped: false) { rect in
            NSColor(hue: hue, saturation: 0.45, brightness: 0.85, alpha: 1).setFill()
            rect.fill()
            return true
        }
    }
}
