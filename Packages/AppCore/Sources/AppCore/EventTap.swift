import CoreGraphics
import Dispatch
import os

@MainActor
@safe
final class EventTap {
    private static let hangMilliseconds = 250
    private static let hang: Duration = .milliseconds(hangMilliseconds)

    var onUnresponsive: (@MainActor () -> Void)?
    var isPaused = false {
        didSet { _ = install(mask) }
    }

    private let logger = Log.logger("EventTap")
    private let signposter = Log.signposter("EventTap")
    private var routes = EventRoutes()
    private(set) var port: CFMachPort?
    private var source: CFRunLoopSource?
    private var installedMask: CGEventMask = 0
    private var isReleasing = false

    private var mask: CGEventMask {
        isPaused || isReleasing ? 0 : routes.mask
    }

    func add(
        types: [CGEventType], swallow: @escaping @MainActor (CGEventType, CGEvent) -> Bool
    ) -> UInt? {
        installed(routes.add(types: types, swallow: swallow))
    }

    func observe(
        types: [CGEventType], observe: @escaping @MainActor (CGEventType, CGEvent) -> Void
    ) -> UInt? {
        installed(routes.observe(types: types, observe: observe))
    }

    func remove(_ id: UInt) {
        routes.remove(id)
        _ = install(mask)
    }

    func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        switch type {
        case .tapDisabledByUserInput:
            if let port {
                CGEvent.tapEnable(tap: port, enable: true)
            }
            return true

        case .tapDisabledByTimeout:
            release("macOS found it unresponsive")
            return true

        default:
            let clock = ContinuousClock()
            let start = clock.now
            let state = signposter.beginInterval("dispatch")
            let swallowed = routes.dispatch(type, event)
            signposter.endInterval("dispatch", state)
            if clock.now - start >= Self.hang {
                release("a route held an event past \(Self.hang)")
            }
            return !swallowed
        }
    }

    private func release(_ reason: String) {
        isReleasing = true
        if let port {
            CGEvent.tapEnable(tap: port, enable: false)
        }
        logger.error("Released the event tap: \(reason, privacy: .public)")
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            isReleasing = false
            isPaused = true
            onUnresponsive?()
        }
    }

    private func installed(_ id: UInt) -> UInt? {
        guard install(mask) else {
            routes.remove(id)
            return nil
        }
        return id
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
