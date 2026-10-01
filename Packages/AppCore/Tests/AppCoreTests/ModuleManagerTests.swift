import Foundation
import Testing

@testable import AppCore

@MainActor
@Suite struct ModuleManagerTests {
    final class FakeModule: Module {
        let descriptor: ModuleDescriptor
        var starts = 0
        var stops = 0
        var failOnStart = false
        var ticks = 0
        var released: [String] = []

        init(id: String, enabledByDefault: Bool) {
            descriptor = ModuleDescriptor(
                id: id, name: id, enabledByDefault: enabledByDefault)
        }

        func start(context: ModuleContext) throws {
            starts += 1
            context.scheduleTimer("poll", interval: 60) { [weak self] in
                self?.ticks += 1
            }
            context.own(.observer, "frontmost") { [weak self] in
                self?.released.append("frontmost")
            }
            context.run("watch") {
                while !Task.isCancelled {
                    await Task.yield()
                }
            }
            if failOnStart {
                throw StartFailure()
            }
        }

        func stop() {
            stops += 1
        }
    }

    struct StartFailure: Error {}

    func makeStore() -> SettingsStore {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        return SettingsStore(url: dir.appending(path: "settings.json"))
    }

    @Test func enablingAndDisablingCallsStartAndStop() throws {
        let manager = try ModuleManager(store: makeStore())
        let module = FakeModule(id: "clipboard", enabledByDefault: false)
        try manager.register(module)

        try manager.setEnabled("clipboard", true)
        try manager.setEnabled("clipboard", true)
        #expect(module.starts == 1)
        #expect(manager.isEnabled("clipboard"))

        try manager.setEnabled("clipboard", false)
        #expect(module.stops == 1)
        #expect(module.released == ["frontmost"])
        #expect(!manager.isEnabled("clipboard"))
    }

    @Test func disabledModulesHoldNoResources() async throws {
        let manager = try ModuleManager(store: makeStore())
        let first = FakeModule(id: "launcher", enabledByDefault: true)
        let second = FakeModule(id: "clipboard", enabledByDefault: true)
        try manager.register(first)
        try manager.register(second)
        try manager.startEnabledModules()

        #expect(manager.activeResources.count == 6)

        try manager.setEnabled("launcher", false)
        try manager.setEnabled("clipboard", false)
        #expect(manager.activeResources.allSatisfy { $0.kind == .task })

        await manager.drain()
        #expect(manager.activeResources.isEmpty)
    }

    @Test func stateAndDefaultsSurviveARestart() throws {
        let store = makeStore()
        let first = try ModuleManager(store: store)
        try first.register(FakeModule(id: "launcher", enabledByDefault: true))
        try first.register(FakeModule(id: "clipboard", enabledByDefault: false))
        try first.setEnabled("launcher", false)
        try first.setEnabled("clipboard", true)

        let second = try ModuleManager(store: store)
        try second.register(FakeModule(id: "launcher", enabledByDefault: true))
        try second.register(FakeModule(id: "clipboard", enabledByDefault: false))
        try second.register(FakeModule(id: "notes", enabledByDefault: true))
        #expect(!second.isEnabled("launcher"))
        #expect(second.isEnabled("clipboard"))
        #expect(second.isEnabled("notes"))
    }

    @Test func failedStartReleasesResourcesAndStaysDisabled() async throws {
        let store = makeStore()
        let manager = try ModuleManager(store: store)
        let module = FakeModule(id: "clipboard", enabledByDefault: false)
        module.failOnStart = true
        try manager.register(module)

        #expect(throws: StartFailure.self) { try manager.setEnabled("clipboard", true) }
        #expect(module.stops == 1)
        await manager.drain()
        #expect(manager.activeResources.isEmpty)
        #expect(!manager.isEnabled("clipboard"))
        #expect(try store.load() == Settings())
    }

    @Test func duplicateAndUnknownIdsAreRejected() throws {
        let manager = try ModuleManager(store: makeStore())
        try manager.register(FakeModule(id: "launcher", enabledByDefault: false))

        #expect(throws: ModuleError.duplicateModule("launcher")) {
            try manager.register(FakeModule(id: "launcher", enabledByDefault: false))
        }
        #expect(throws: ModuleError.unknownModule("nope")) {
            try manager.setEnabled("nope", true)
        }
    }
}
