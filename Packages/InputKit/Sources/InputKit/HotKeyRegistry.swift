public import AppCore

@MainActor
public final class HotKeyRegistry {
    private struct Entry {
        let shortcut: Shortcut
        let handler: @MainActor () -> Void
    }

    private let backend: any HotKeyBackend
    private var entries: [UInt32: Entry] = [:]
    private var nextID: UInt32 = 1

    public var isSuspended = false {
        didSet {
            guard isSuspended != oldValue else { return }
            for (id, entry) in entries {
                if isSuspended {
                    backend.unregister(id: id)
                } else {
                    _ = backend.register(entry.shortcut, id: id)
                }
            }
        }
    }

    public convenience init() throws(HotKeyError) {
        self.init(backend: try CarbonHotKeyBackend())
    }

    init(backend: any HotKeyBackend) {
        self.backend = backend
        backend.onPressed = { [weak self] id in
            self?.fire(id)
        }
    }

    @discardableResult
    public func register(
        _ shortcut: Shortcut, name: String, context: ModuleContext,
        handler: @escaping @MainActor () -> Void
    ) throws(HotKeyError) -> HotKeyRegistration {
        let registration = try register(shortcut, handler: handler)
        context.own(.other, name) { [weak self] in
            MainActor.assumeIsolated { self?.unregister(registration) }
        }
        return registration
    }

    @discardableResult
    public func register(
        _ shortcut: Shortcut, handler: @escaping @MainActor () -> Void
    ) throws(HotKeyError) -> HotKeyRegistration {
        if entries.values.contains(where: { $0.shortcut == shortcut }) {
            throw .duplicate(shortcut)
        }
        let id = nextID
        let status = isSuspended ? 0 : backend.register(shortcut, id: id)
        guard status == 0 else {
            throw .refused(status)
        }
        nextID += 1
        entries[id] = Entry(shortcut: shortcut, handler: handler)
        return HotKeyRegistration(id: id)
    }

    public func accepts(_ shortcut: Shortcut) -> Bool {
        guard !entries.values.contains(where: { $0.shortcut == shortcut }) else { return false }
        let status = backend.register(shortcut, id: nextID)
        if status == 0 {
            backend.unregister(id: nextID)
        }
        return status == 0
    }

    public func unregister(_ registration: HotKeyRegistration) {
        if entries.removeValue(forKey: registration.id) != nil, !isSuspended {
            backend.unregister(id: registration.id)
        }
    }

    func fire(_ id: UInt32) {
        entries[id]?.handler()
    }
}
