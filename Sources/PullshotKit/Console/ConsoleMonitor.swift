import Foundation
import IOKit

/// 스위치가 꽂히거나 빠질 때 알립니다. PC로 복사 모드를 켜고 끌 때도 제품 ID가 바뀌어 다시 붙으므로 함께 알립니다.
/// 무엇이 바뀌었는지는 담지 않으므로, 받으면 `ConsoleLocator`로 다시 찾습니다. 감시를 놓으면 `changes`가 끝납니다.
public final class ConsoleMonitor {
    public let changes: AsyncStream<Void>

    private let continuation: AsyncStream<Void>.Continuation
    private let queue = DispatchQueue(label: "com.parkgiraffe.Pullshot.console-monitor")
    private let port: IONotificationPortRef
    private var notifications: [io_iterator_t] = []

    public init() {
        // 살피기는 지금 꽂힌 기기를 모두 다시 찾으므로 밀린 알림은 하나면 됩니다.
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
            // 처음 비우기는 알림을 켜는 일이라 알리지 않습니다.
            drain(notification)
            notifications.append(notification)
        }
    }

    /// 알림 처리가 도는 큐에서 포트를 닫아, 처리 중이거나 그 뒤에 오는 알림이 놓인 감시를 건드리지 않게 합니다.
    deinit {
        queue.sync {
            notifications.forEach { IOObjectRelease($0) }
            IONotificationPortDestroy(port)
        }
        continuation.finish()
    }
}

/// 알림 반복자를 끝까지 비웁니다. 비워야 다음 알림이 켜집니다.
private func drain(_ notification: io_iterator_t) {
    while case let service = IOIteratorNext(notification), service != 0 {
        IOObjectRelease(service)
    }
}
