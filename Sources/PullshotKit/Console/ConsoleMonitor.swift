import Foundation
import IOKit

public final class ConsoleMonitor {
    public let changes: AsyncStream<Void>

    private let continuation: AsyncStream<Void>.Continuation
    private let queue = DispatchQueue(label: "com.parkgiraffe.Pullshot.console-monitor")
    private let port: IONotificationPortRef
    private var notifications: [io_iterator_t] = []

    public init() {
        (changes, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
        port = IONotificationPortCreate(kIOMainPortDefault)
        IONotificationPortSetDispatchQueue(port, queue)
        let productIDs = ConsoleModel.all.map(\.productID) + ConsoleModel.all.compactMap(\.idleProductID)
        for type in [kIOFirstMatchNotification, kIOTerminatedNotification] {
            var notification: io_iterator_t = 0
            let result = IOServiceAddMatchingNotification(
                port,
                type,
                ConsoleLocator.matchingDictionary(productIDs: productIDs),
                { monitor, notification in
                    drain(notification)
                    guard let monitor else { return }
                    Unmanaged<ConsoleMonitor>.fromOpaque(monitor).takeUnretainedValue().continuation.yield()
                },
                Unmanaged.passUnretained(self).toOpaque(),
                &notification
            )
            guard result == KERN_SUCCESS else {
                Log.usb.error("기기 알림을 걸지 못했습니다: \(String(format: "0x%08X", result), privacy: .public)")
                continue
            }
            drain(notification)
            notifications.append(notification)
        }
    }

    deinit {
        queue.sync {
            notifications.forEach { IOObjectRelease($0) }
            IONotificationPortDestroy(port)
        }
        continuation.finish()
    }
}

private func drain(_ notification: io_iterator_t) {
    while case let service = IOIteratorNext(notification), service != 0 {
        IOObjectRelease(service)
    }
}
