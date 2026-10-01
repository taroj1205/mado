import AppCore
import Carbon

@MainActor
@safe
final class CarbonHotKeyBackend: HotKeyBackend {
    static let signature: OSType = 0x4D41_444F

    var onPressed: (@MainActor (UInt32) -> Void)?

    private var refs: [UInt32: EventHotKeyRef] = unsafe [:]
    private var handler: EventHandlerRef?

    init() throws(HotKeyError) {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = unsafe InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userDataRef in
                guard let event = unsafe eventRef, let userData = unsafe userDataRef else {
                    return OSStatus(eventNotHandledErr)
                }
                var hotKeyID = EventHotKeyID()
                let status = unsafe GetEventParameter(
                    event, EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID), nil,
                    MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
                guard status == noErr else {
                    return OSStatus(eventNotHandledErr)
                }
                let backend = unsafe Unmanaged<CarbonHotKeyBackend>.fromOpaque(userData)
                    .takeUnretainedValue()
                let handled = MainActor.assumeIsolated { backend.dispatch(hotKeyID) }
                return handled ? noErr : OSStatus(eventNotHandledErr)
            },
            1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else {
            throw .handlerInstallFailed(status)
        }
    }

    static func carbonModifiers(_ modifiers: Shortcut.Modifiers) -> UInt32 {
        var mask = 0
        if modifiers.contains(.command) { mask |= cmdKey }
        if modifiers.contains(.control) { mask |= controlKey }
        if modifiers.contains(.option) { mask |= optionKey }
        if modifiers.contains(.shift) { mask |= shiftKey }
        return UInt32(mask)
    }

    func dispatch(_ hotKeyID: EventHotKeyID) -> Bool {
        guard hotKeyID.signature == Self.signature else {
            return false
        }
        onPressed?(hotKeyID.id)
        return true
    }

    func register(_ shortcut: Shortcut, id: UInt32) -> Int32 {
        var pending: EventHotKeyRef?
        let status = unsafe RegisterEventHotKey(
            shortcut.keyCode, Self.carbonModifiers(shortcut.modifiers),
            EventHotKeyID(signature: Self.signature, id: id),
            GetApplicationEventTarget(), 0, &pending)
        if status == noErr, let created = unsafe pending {
            unsafe refs[id] = created
        }
        return status
    }

    func unregister(id: UInt32) {
        if let ref = unsafe refs.removeValue(forKey: id) {
            unsafe _ = UnregisterEventHotKey(ref)
        }
    }

    isolated deinit {
        let registered = unsafe Array(refs.keys)
        for id in registered {
            unregister(id: id)
        }
        if let installed = unsafe handler {
            unsafe _ = RemoveEventHandler(installed)
        }
    }
}
