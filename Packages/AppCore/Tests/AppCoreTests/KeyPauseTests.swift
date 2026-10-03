import CoreGraphics
import Foundation
import Testing

@testable import AppCore

@MainActor
@Suite struct KeyPauseTests {
    final class KeyModule: Module {
        let descriptor: ModuleDescriptor
        let hasKeys: Bool
        var starts = 0
        var stops = 0
        var keyStarts = 0
        var released: [String] = []
        var failOnStart = false

        init(id: String, hasKeys: Bool, enabledByDefault: Bool) {
            descriptor = ModuleDescriptor(id: id, name: id, enabledByDefault: enabledByDefault)
            self.hasKeys = hasKeys
        }

        func start(context: ModuleContext) throws {
            starts += 1
            if failOnStart {
                throw StartFailure()
            }
            context.own(.other, "command") { [weak self] in self?.released.append("command") }
            guard hasKeys else { return }
            context.startKeyFeatures {
                keyStarts += 1
                context.own(.other, "remap") { [weak self] in self?.released.append("remap") }
            }
        }

        func stop() {
            stops += 1
        }
    }

    struct StartFailure: Error {}

    private static let holdSeconds = 0.3
    private static let slowMark: Int64 = 0x4D61646F

    private static func makeManager() throws -> ModuleManager {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        return try ModuleManager(store: SettingsStore(url: dir.appending(path: "settings.json")))
    }

    private static func mainQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    @Test func aTapMacOSFoundUnresponsivePausesEveryKeyFeature() async throws {
        let manager = try Self.makeManager()
        let keyboard = KeyModule(id: "keyboard", hasKeys: true, enabledByDefault: true)
        try manager.register(keyboard)
        try manager.startEnabledModules()
        var changes = 0
        manager.onKeysPausedChange = { changes += 1 }
        let event = try #require(CGEvent(source: nil))

        #expect(manager.eventTap.handle(.tapDisabledByTimeout, event))
        #expect(!manager.keysPaused)
        await Self.mainQueue()
        #expect(manager.keysPaused)
        #expect(manager.eventTap.isPaused)
        #expect(changes == 1)
        #expect(keyboard.released.contains("remap"))
        #expect(!manager.activeResources.contains { $0.name == "remap" })
    }

    @Test func onlyADispatchPastTheHangLimitAsksForTheTapToBeReleased() async throws {
        let tap = EventTap()
        var released = 0
        tap.onUnresponsive = { released += 1 }
        tap.isPaused = true
        let id = try #require(
            tap.add(types: [.keyDown]) { _, event in
                if event.getIntegerValueField(.eventSourceUserData) == Self.slowMark {
                    Thread.sleep(forTimeInterval: Self.holdSeconds)
                }
                return true
            })
        defer { tap.remove(id) }
        let quick = try #require(CGEvent(source: nil))
        let slow = try #require(CGEvent(source: nil))
        slow.setIntegerValueField(.eventSourceUserData, value: Self.slowMark)

        #expect(!tap.handle(.keyDown, quick))
        await Self.mainQueue()
        #expect(released == 0)

        #expect(!tap.handle(.keyDown, slow))
        await Self.mainQueue()
        #expect(released == 1)
    }

    @Test func aRouteAddedBeforeTheReleaseLandsDoesNotInstallATap() async throws {
        let tap = EventTap()
        var released = 0
        tap.onUnresponsive = { released += 1 }
        let event = try #require(CGEvent(source: nil))

        #expect(tap.handle(.tapDisabledByTimeout, event))
        let id = tap.add(types: [.keyDown]) { _, _ in false }
        let portBeforeTheRelease = tap.port
        await Self.mainQueue()
        if let id {
            tap.remove(id)
        }

        #expect(id != nil)
        #expect(portBeforeTheRelease == nil)
        #expect(tap.isPaused)
        #expect(released == 1)
    }

    @Test func pausingRestartsOnlyModulesWithKeyFeaturesWithoutThem() throws {
        let manager = try Self.makeManager()
        let keyboard = KeyModule(id: "keyboard", hasKeys: true, enabledByDefault: true)
        let calculator = KeyModule(id: "calculator", hasKeys: false, enabledByDefault: true)
        try manager.register(keyboard)
        try manager.register(calculator)
        try manager.startEnabledModules()
        var changes = 0
        manager.onKeysPausedChange = { changes += 1 }

        manager.setKeysPaused(true)
        manager.setKeysPaused(true)
        #expect(manager.keysPaused)
        #expect(changes == 1)
        #expect(keyboard.stops == 1)
        #expect(keyboard.starts == 2)
        #expect(keyboard.keyStarts == 1)
        #expect(keyboard.released.sorted() == ["command", "remap"])
        #expect(calculator.stops == 0)
        #expect(calculator.starts == 1)
        #expect(!manager.activeResources.contains { $0.name == "remap" })
        #expect(
            manager.activeResources.contains { $0.module == "keyboard" && $0.name == "command" })

        manager.setKeysPaused(false)
        #expect(!manager.keysPaused)
        #expect(changes == 2)
        #expect(keyboard.keyStarts == 2)
        #expect(manager.activeResources.contains { $0.name == "remap" })
        #expect(calculator.starts == 1)
    }

    @Test func aModuleTurnedOnOrAddedWhilePausedWaitsForTheResume() throws {
        let manager = try Self.makeManager()
        let dictation = KeyModule(id: "dictation", hasKeys: true, enabledByDefault: false)
        try manager.register(dictation)
        manager.setKeysPaused(true)
        let windows = KeyModule(id: "windows", hasKeys: true, enabledByDefault: true)
        try manager.register(windows)

        try manager.startEnabledModules()
        try manager.setEnabled("dictation", true)
        #expect(dictation.starts == 1)
        #expect(windows.starts == 1)
        #expect(dictation.keyStarts == 0)
        #expect(windows.keyStarts == 0)

        manager.setKeysPaused(false)
        #expect(dictation.keyStarts == 1)
        #expect(windows.keyStarts == 1)
    }

    @Test func aModuleThatFailsToRestartIsTriedAgainOnTheNextChange() throws {
        let manager = try Self.makeManager()
        let keyboard = KeyModule(id: "keyboard", hasKeys: true, enabledByDefault: true)
        let windows = KeyModule(id: "windows", hasKeys: true, enabledByDefault: true)
        let clipboard = KeyModule(id: "clipboard", hasKeys: true, enabledByDefault: true)
        try manager.register(keyboard)
        try manager.register(windows)
        try manager.register(clipboard)
        try manager.startEnabledModules()
        try manager.setEnabled("clipboard", false)
        var changes = 0
        manager.onKeysPausedChange = { changes += 1 }

        keyboard.failOnStart = true
        manager.setKeysPaused(true)
        #expect(changes == 1)
        #expect(keyboard.stops == 2)
        #expect(windows.starts == 2)
        #expect(manager.activeResources.allSatisfy { $0.module == "windows" })

        keyboard.failOnStart = false
        manager.setKeysPaused(false)
        #expect(keyboard.starts == 3)
        #expect(keyboard.keyStarts == 2)
        #expect(windows.keyStarts == 2)
        #expect(clipboard.starts == 1)
    }

    @Test func aContextStartsKeyFeaturesOnlyWhileTheyAreOn() {
        let context = ModuleContext(
            moduleID: "keyboard", commands: CommandRegistry(), eventTap: EventTap())
        var started = 0
        context.keysPaused = true
        context.startKeyFeatures { started += 1 }
        #expect(started == 0)
        #expect(context.hasKeyFeatures)

        context.keysPaused = false
        context.startKeyFeatures { started += 1 }
        #expect(started == 1)
    }
}
