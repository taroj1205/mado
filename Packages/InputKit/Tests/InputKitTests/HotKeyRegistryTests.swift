import AppCore
import Carbon
import Foundation
import Testing

@testable import InputKit

@MainActor
@Suite struct HotKeyRegistryTests {
    final class FakeBackend: HotKeyBackend {
        var onPressed: (@MainActor (UInt32) -> Void)?
        var registered: [UInt32: Shortcut] = [:]
        var status: Int32 = 0

        func register(_ shortcut: Shortcut, id: UInt32) -> Int32 {
            if status == 0 {
                registered[id] = shortcut
            }
            return status
        }

        func unregister(id: UInt32) {
            registered[id] = nil
        }
    }

    final class HotKeyModule: Module {
        let descriptor: ModuleDescriptor
        let registry: HotKeyRegistry
        var fired = 0
        var stops = 0

        init(registry: HotKeyRegistry, id: String) {
            descriptor = ModuleDescriptor(id: id, name: id, enabledByDefault: true)
            self.registry = registry
        }

        func start(context: ModuleContext) throws {
            try registry.register(
                HotKeyRegistryTests.shortcut, name: "test", context: context
            ) { [weak self] in
                self?.fired += 1
            }
        }

        func stop() {
            stops += 1
        }
    }

    static let shortcut = Shortcut(
        keyCode: 80, modifiers: [.command, .control, .option, .shift])

    func makeManager() throws -> ModuleManager {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        return try ModuleManager(store: SettingsStore(url: dir.appending(path: "settings.json")))
    }

    func postHotKeyPressed(id: UInt32) throws {
        var event: EventRef?
        try #require(
            unsafe CreateEvent(
                nil, OSType(kEventClassKeyboard), UInt32(kEventHotKeyPressed), 0,
                EventAttributes(kEventAttributeNone), &event) == noErr)
        guard let created = unsafe event else {
            Issue.record("CreateEvent returned no event")
            return
        }
        var hotKeyID = EventHotKeyID(signature: CarbonHotKeyBackend.signature, id: id)
        try #require(
            unsafe SetEventParameter(
                created, EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID), MemoryLayout<EventHotKeyID>.size,
                &hotKeyID) == noErr)
        try #require(unsafe SendEventToEventTarget(created, GetApplicationEventTarget()) == noErr)
        unsafe ReleaseEvent(created)
    }

    @Test func modifiersMapToCarbonMasks() {
        let all = CarbonHotKeyBackend.carbonModifiers([.command, .control, .option, .shift])
        #expect(all == UInt32(cmdKey | controlKey | optionKey | shiftKey))
        #expect(CarbonHotKeyBackend.carbonModifiers(.command) == UInt32(cmdKey))
        #expect(CarbonHotKeyBackend.carbonModifiers([]) == 0)
    }

    @Test func registerFireUnregisterThroughCarbon() throws {
        let registry = try HotKeyRegistry()
        let manager = try makeManager()
        let module = HotKeyModule(registry: registry, id: "hotkey-test")
        try manager.register(module)
        try manager.startEnabledModules()

        try postHotKeyPressed(id: 1)
        #expect(module.fired == 1)

        try manager.setEnabled("hotkey-test", false)
        try postHotKeyPressed(id: 1)
        #expect(module.fired == 1)
    }

    @Test func duplicateRegistrationIsRejected() throws {
        let backend = FakeBackend()
        let registry = HotKeyRegistry(backend: backend)
        let manager = try makeManager()
        try manager.register(HotKeyModule(registry: registry, id: "hotkey-test"))
        try manager.register(HotKeyModule(registry: registry, id: "second"))

        #expect(throws: HotKeyError.duplicate(Self.shortcut)) {
            try manager.startEnabledModules()
        }
        #expect(backend.registered.count == 1)
    }

    @Test func osRefusalIsReported() throws {
        let backend = FakeBackend()
        backend.status = -9_878
        let registry = HotKeyRegistry(backend: backend)
        let manager = try makeManager()
        let module = HotKeyModule(registry: registry, id: "hotkey-test")
        try manager.register(module)

        #expect(throws: HotKeyError.refused(-9_878)) {
            try manager.startEnabledModules()
        }
    }

    @Test func routesByIDAndStopsAfterUnregister() throws {
        let backend = FakeBackend()
        let registry = HotKeyRegistry(backend: backend)
        let manager = try makeManager()
        let module = HotKeyModule(registry: registry, id: "hotkey-test")
        try manager.register(module)
        try manager.startEnabledModules()

        backend.onPressed?(1)
        backend.onPressed?(99)
        #expect(module.fired == 1)

        try manager.setEnabled("hotkey-test", false)
        backend.onPressed?(1)
        #expect(module.fired == 1)
        #expect(backend.registered.isEmpty)
        #expect(module.stops == 1)
    }
}
