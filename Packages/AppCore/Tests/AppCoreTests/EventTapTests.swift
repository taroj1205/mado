import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@testable import AppCore

@MainActor
@Suite(.enabled(if: AXIsProcessTrusted(), "Active event taps need Accessibility"))
struct EventTapTests {
    @MainActor
    final class SlowKeysModule: Module {
        let descriptor = ModuleDescriptor(id: "keyboard", name: "Keyboard", enabledByDefault: true)
        var holds = true
        var remapsRestored = 0
        var stops = 0

        func start(context: ModuleContext) {
            context.startKeyFeatures {
                let hold = { [weak self] in self?.holds == true }
                try? context.tapEvents("slow keys", matching: [EventTapTests.idle]) { _, _ in
                    if hold() {
                        Thread.sleep(forTimeInterval: EventTapTests.holdSeconds)
                    }
                    return false
                }
                context.own(.other, "remap") { [weak self] in self?.remapsRestored += 1 }
            }
        }

        func stop() {
            stops += 1
        }
    }

    static let idle = CGEventType.tabletProximity
    static let holdSeconds = 0.3
    private static let slowMark: Int64 = 0x4D61646F

    private static func mainQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    @Test func aTapTheUserTurnedOffIsReenabledRightAway() throws {
        let tap = EventTap()
        let id = try #require(tap.add(types: [.flagsChanged]) { _, _ in false })
        defer { tap.remove(id) }
        let port = try #require(tap.port)
        let event = try #require(CGEvent(source: nil))

        CGEvent.tapEnable(tap: port, enable: false)
        #expect(!CGEvent.tapIsEnabled(tap: port))
        #expect(tap.handle(.tapDisabledByUserInput, event))
        #expect(CGEvent.tapIsEnabled(tap: port))
    }

    @Test func aTapMacOSFoundUnresponsiveIsReleasedNotReenabled() async throws {
        let tap = EventTap()
        var released = 0
        tap.onUnresponsive = { released += 1 }
        let id = try #require(tap.add(types: [Self.idle]) { _, _ in false })
        defer { tap.remove(id) }
        let port = try #require(tap.port)
        let event = try #require(CGEvent(source: nil))

        CGEvent.tapEnable(tap: port, enable: false)
        #expect(tap.handle(.tapDisabledByTimeout, event))
        #expect(!CGEvent.tapIsEnabled(tap: port))
        await Self.mainQueue()
        #expect(released == 1)
        #expect(tap.isPaused)
        #expect(tap.port == nil)
        #expect(!CFMachPortIsValid(port))
    }

    @Test func aRouteThatHoldsAnEventReleasesTheTapAndTheEventStillPasses() async throws {
        let tap = EventTap()
        var released = 0
        tap.onUnresponsive = { released += 1 }
        let id = try #require(
            tap.add(types: [Self.idle]) { _, event in
                if event.getIntegerValueField(.eventSourceUserData) == Self.slowMark {
                    Thread.sleep(forTimeInterval: Self.holdSeconds)
                }
                return false
            })
        defer { tap.remove(id) }
        let port = try #require(tap.port)
        let quick = try #require(CGEvent(source: nil))
        let slow = try #require(CGEvent(source: nil))
        slow.setIntegerValueField(.eventSourceUserData, value: Self.slowMark)

        #expect(tap.handle(Self.idle, quick))
        await Self.mainQueue()
        #expect(released == 0)
        #expect(CGEvent.tapIsEnabled(tap: port))

        #expect(tap.handle(Self.idle, slow))
        #expect(!CGEvent.tapIsEnabled(tap: port))
        await Self.mainQueue()
        #expect(released == 1)
        #expect(tap.port == nil)
    }

    @Test func aPausedTapKeepsItsRoutesAndComesBackWithThem() throws {
        let tap = EventTap()
        let first = try #require(tap.add(types: [Self.idle]) { _, _ in false })
        defer { tap.remove(first) }
        tap.isPaused = true
        #expect(tap.port == nil)

        let second = try #require(tap.add(types: [Self.idle]) { _, _ in false })
        defer { tap.remove(second) }
        #expect(tap.port == nil)

        tap.isPaused = false
        #expect(tap.port != nil)
    }

    @Test func aSlowRoutePausesEveryKeyFeatureUntilResumed() async throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let manager = try ModuleManager(
            store: SettingsStore(url: dir.appending(path: "settings.json")))
        let module = SlowKeysModule()
        try manager.register(module)
        try manager.startEnabledModules()
        var changes = 0
        manager.onKeysPausedChange = { changes += 1 }
        let event = try #require(CGEvent(source: nil))
        #expect(manager.eventTap.port != nil)

        #expect(manager.eventTap.handle(Self.idle, event))
        await Self.mainQueue()
        #expect(manager.keysPaused)
        #expect(changes == 1)
        #expect(manager.eventTap.port == nil)
        #expect(manager.activeResources.isEmpty)
        #expect(module.remapsRestored == 1)
        #expect(module.stops == 1)

        module.holds = false
        manager.setKeysPaused(false)
        #expect(manager.eventTap.port != nil)
        #expect(
            manager.activeResources == [
                ActiveResource(module: "keyboard", kind: .eventTap, name: "slow keys"),
                ActiveResource(module: "keyboard", kind: .other, name: "remap"),
            ])
        try manager.setEnabled("keyboard", false)
    }

    @Test func theRoutesDecideWhatIsSwallowed() throws {
        let tap = EventTap()
        let id = try #require(tap.add(types: [.keyDown, .keyUp]) { type, _ in type == .keyDown })
        defer { tap.remove(id) }
        let event = try #require(CGEvent(source: nil))

        #expect(!tap.handle(.keyDown, event))
        #expect(tap.handle(.keyUp, event))
    }

    @Test func allRoutesShareOneTapThatGoesAwayWithTheLast() throws {
        let tap = EventTap()
        let radial = try #require(tap.add(types: [.flagsChanged]) { _, _ in false })
        let first = try #require(tap.port)

        let modifier = try #require(tap.add(types: [.flagsChanged]) { _, _ in false })
        #expect(tap.port === first)

        let snippets = try #require(tap.add(types: [.keyDown]) { _, _ in false })
        let widened = try #require(tap.port)
        #expect(widened !== first)
        #expect(!CFMachPortIsValid(first))

        tap.remove(radial)
        tap.remove(modifier)
        #expect(tap.port !== widened)
        tap.remove(snippets)
        #expect(tap.port == nil)
    }

    @Test func theContextOwnsItsRouteUntilReleased() throws {
        let tap = EventTap()
        let context = ModuleContext(moduleID: "radial", commands: CommandRegistry(), eventTap: tap)
        try context.tapEvents("trigger", matching: [.flagsChanged]) { _, _ in false }
        #expect(
            context.active == [ActiveResource(module: "radial", kind: .eventTap, name: "trigger")])
        #expect(tap.port != nil)

        context.releaseAll()
        #expect(context.active.isEmpty)
        #expect(tap.port == nil)
    }

    @Test func anObserverIsOwnedLikeAnyOtherRoute() throws {
        let tap = EventTap()
        let context = ModuleContext(moduleID: "keys", commands: CommandRegistry(), eventTap: tap)
        var observed = 0
        try context.observeEvents("taps", matching: [.flagsChanged]) { _, _ in observed += 1 }
        #expect(context.active == [ActiveResource(module: "keys", kind: .eventTap, name: "taps")])
        let event = try #require(CGEvent(source: nil))
        #expect(tap.handle(.flagsChanged, event))
        #expect(observed == 1)

        context.releaseAll()
        #expect(tap.port == nil)
    }
}
