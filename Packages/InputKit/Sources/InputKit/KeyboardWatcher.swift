import CoreFoundation
import Dispatch
import Foundation
import IOKit
import IOKit.hid

@MainActor
@safe
public final class KeyboardWatcher {
    private static let settleDelay = DispatchTimeInterval.seconds(1)

    private let onChange: @MainActor () -> Void
    private let port: IONotificationPortRef?
    private var iterators: [io_iterator_t] = []

    public init(onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
        unsafe port = IONotificationPortCreate(kIOMainPortDefault)
        guard let notifications = unsafe port else { return }
        let source = unsafe IONotificationPortGetRunLoopSource(notifications).takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        for type in [kIOFirstMatchNotification, kIOTerminatedNotification] {
            var iterator: io_iterator_t = 0
            let status = unsafe IOServiceAddMatchingNotification(
                notifications, type, Self.matching(),
                { refcon, added in
                    guard let info = unsafe refcon else { return }
                    let watcher = unsafe Unmanaged<KeyboardWatcher>.fromOpaque(info)
                        .takeUnretainedValue()
                    MainActor.assumeIsolated { watcher.changed(added) }
                },
                unsafe Unmanaged.passUnretained(self).toOpaque(), &iterator)
            guard status == KERN_SUCCESS else { continue }
            Self.drain(iterator)
            iterators.append(iterator)
        }
    }

    private static func matching() -> CFDictionary {
        let matching: [String: Any] = [
            kIOProviderClassKey: "IOHIDEventService",
            kIOPropertyMatchKey: [
                kIOHIDPrimaryUsagePageKey: kHIDPage_GenericDesktop,
                kIOHIDPrimaryUsageKey: kHIDUsage_GD_Keyboard,
            ],
        ]
        return matching as CFDictionary
    }

    private static func drain(_ iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            IOObjectRelease(service)
        }
    }

    private func changed(_ iterator: io_iterator_t) {
        Self.drain(iterator)
        onChange()
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.settleDelay) { [weak self] in
            self?.onChange()
        }
    }

    isolated deinit {
        for iterator in iterators {
            IOObjectRelease(iterator)
        }
        if let notifications = unsafe port {
            unsafe IONotificationPortDestroy(notifications)
        }
    }
}
