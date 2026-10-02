import CoreGraphics
import os

@MainActor
@safe
final class EventTap {
    private let signposter = Log.signposter("EventTap")
    private var routes = EventRoutes()
    private(set) var port: CFMachPort?
    private var source: CFRunLoopSource?
    private var installedMask: CGEventMask = 0

    func add(
        types: [CGEventType], swallow: @escaping @MainActor (CGEventType, CGEvent) -> Bool
    ) -> UInt? {
        let id = routes.add(types: types, swallow: swallow)
        guard install(routes.mask) else {
            routes.remove(id)
            return nil
        }
        return id
    }

    func remove(_ id: UInt) {
        routes.remove(id)
        _ = install(routes.mask)
    }

    func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let port {
                CGEvent.tapEnable(tap: port, enable: true)
            }
            return true
        }
        let state = signposter.beginInterval("dispatch")
        defer { signposter.endInterval("dispatch", state) }
        return !routes.dispatch(type, event)
    }

    private func install(_ mask: CGEventMask) -> Bool {
        guard mask != installedMask else { return true }
        guard mask != 0 else {
            invalidate()
            return true
        }
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
            return false
        }
        invalidate()
        let runLoopSource = CFMachPortCreateRunLoopSource(nil, created, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        port = created
        source = runLoopSource
        installedMask = mask
        return true
    }

    private func invalidate() {
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let port {
            CFMachPortInvalidate(port)
        }
        port = nil
        source = nil
        installedMask = 0
    }

    isolated deinit {
        invalidate()
    }
}
