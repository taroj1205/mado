import CoreGraphics

@MainActor
@safe
final class EventTap {
    private let swallow: @MainActor (CGEventType, CGEvent) -> Bool
    private(set) var port: CFMachPort?
    private var source: CFRunLoopSource?

    init?(types: [CGEventType], swallow: @escaping @MainActor (CGEventType, CGEvent) -> Bool) {
        self.swallow = swallow
        let mask = types.reduce(CGEventMask(0)) { $0 | 1 << $1.rawValue }
        guard
            let created = unsafe CGEvent.tapCreate(
                tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                eventsOfInterest: mask,
                callback: { _, type, event, userInfo in
                    guard let info = unsafe userInfo else {
                        return unsafe Unmanaged.passUnretained(event)
                    }
                    let tap = unsafe Unmanaged<EventTap>.fromOpaque(info)
                        .takeUnretainedValue()
                    let passes = MainActor.assumeIsolated { tap.handle(type, event) }
                    return passes ? unsafe Unmanaged.passUnretained(event) : nil
                },
                userInfo: unsafe Unmanaged.passUnretained(self).toOpaque())
        else {
            return nil
        }
        let runLoopSource = CFMachPortCreateRunLoopSource(nil, created, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        port = created
        source = runLoopSource
    }

    func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let port {
                CGEvent.tapEnable(tap: port, enable: true)
            }
            return true
        }
        return !swallow(type, event)
    }

    func invalidate() {
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let port {
            CFMachPortInvalidate(port)
        }
        port = nil
        source = nil
    }

    isolated deinit {
        invalidate()
    }
}
