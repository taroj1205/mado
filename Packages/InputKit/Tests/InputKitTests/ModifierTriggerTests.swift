import AppCore
import ApplicationServices
import Carbon.HIToolbox
import CoreGraphics
import Foundation
import Testing

@testable import InputKit

@Suite struct ModifierTriggerTests {
    final class Recorder {
        var trigger: ModifierTrigger
        var events: [ModifierTrigger.Event] = []

        init(_ modifiers: Shortcut.Modifiers) {
            trigger = ModifierTrigger(modifiers: modifiers)
        }

        func send(_ type: CGEventType, _ flags: CGEventFlags) -> Bool {
            send(type, flags, keyCode: kVK_ANSI_A)
        }

        func send(_ type: CGEventType, _ flags: CGEventFlags, keyCode: Int) -> Bool {
            trigger.handle(type, flags: flags, keyCode: Int64(keyCode)) { events.append($0) }
        }
    }

    final class RadialModule: Module {
        let descriptor = ModuleDescriptor(id: "radial", name: "Radial", enabledByDefault: true)
        var events: [ModifierTrigger.Event] = []
        var stops = 0

        func start(context: ModuleContext) throws {
            try ModifierTrigger.install(
                ModifierTriggerTests.chord, name: "trigger", context: context
            ) { [weak self] event in self?.events.append(event) }
        }

        func stop() {
            stops += 1
        }
    }

    @MainActor
    final class Inbox {
        var events: [ModifierTrigger.Event] = []
    }

    static let chord: Shortcut.Modifiers = [.control, .option]
    static let held: CGEventFlags = [.maskControl, .maskAlternate]

    @Test func pressAndReleaseOfTheExactModifiersAreReported() {
        let recorder = Recorder(Self.chord)
        #expect(!recorder.send(.flagsChanged, .maskControl))
        #expect(!recorder.send(.flagsChanged, Self.held.union(.maskAlphaShift)))
        #expect(!recorder.send(.flagsChanged, Self.held.union(.maskCommand)))
        #expect(!recorder.send(.flagsChanged, Self.held))
        #expect(!recorder.send(.flagsChanged, []))
        #expect(recorder.events == [.pressed, .released, .pressed, .released])
    }

    @Test func clicksWhileHeldAreSwallowedThroughTheirMouseUp() {
        let recorder = Recorder(Self.chord)
        #expect(!recorder.send(.leftMouseDown, []))
        #expect(!recorder.send(.leftMouseUp, []))
        _ = recorder.send(.flagsChanged, Self.held)
        #expect(recorder.send(.leftMouseDown, Self.held))
        _ = recorder.send(.flagsChanged, [])
        #expect(recorder.send(.leftMouseDragged, []))
        #expect(recorder.send(.leftMouseUp, []))
        #expect(!recorder.send(.leftMouseDown, []))
        #expect(!recorder.send(.leftMouseDragged, []))
        #expect(recorder.events == [.pressed, .clicked, .released])
    }

    @Test func escapeCancelsOnceAndIsSwallowedUntilKeyUp() {
        let recorder = Recorder(Self.chord)
        #expect(!recorder.send(.keyDown, [], keyCode: kVK_Escape))
        _ = recorder.send(.flagsChanged, Self.held)
        #expect(recorder.send(.keyDown, Self.held, keyCode: kVK_Escape))
        #expect(recorder.send(.keyDown, Self.held, keyCode: kVK_Escape))
        #expect(recorder.send(.keyUp, Self.held, keyCode: kVK_Escape))
        #expect(!recorder.send(.keyDown, Self.held, keyCode: kVK_ANSI_A))
        #expect(!recorder.send(.leftMouseDown, Self.held))
        _ = recorder.send(.flagsChanged, [])
        #expect(recorder.events == [.pressed, .cancelled])
    }

    @Test func aMissedReleaseIsCaughtFromTheNextEventsFlags() {
        let recorder = Recorder(Self.chord)
        _ = recorder.send(.flagsChanged, Self.held)
        #expect(!recorder.send(.leftMouseDown, []))
        #expect(recorder.events == [.pressed, .released])
    }

    @Test func fnAloneOpensAndFnWithControlDoesNot() {
        let recorder = Recorder(.function)
        #expect(!recorder.send(.flagsChanged, .maskSecondaryFn))
        #expect(!recorder.send(.flagsChanged, [.maskSecondaryFn, .maskControl]))
        #expect(!recorder.send(.flagsChanged, [.maskSecondaryFn, .maskControl, .maskAlternate]))
        #expect(!recorder.send(.flagsChanged, []))
        #expect(recorder.events == [.pressed, .released])
    }

    @Test func keysThatCarryTheFnFlagWithoutFnDoNotOpen() {
        let recorder = Recorder(.function)
        for key in [kVK_LeftArrow, kVK_F5, kVK_Home] {
            #expect(!recorder.send(.keyDown, .maskSecondaryFn, keyCode: key))
            #expect(!recorder.send(.keyUp, .maskSecondaryFn, keyCode: key))
        }
        #expect(recorder.events.isEmpty)
    }

    @Test func escapeStillCancelsAnFnTrigger() {
        let recorder = Recorder(.function)
        _ = recorder.send(.flagsChanged, .maskSecondaryFn)
        #expect(recorder.send(.keyDown, .maskSecondaryFn, keyCode: kVK_Escape))
        #expect(recorder.send(.keyUp, .maskSecondaryFn, keyCode: kVK_Escape))
        _ = recorder.send(.flagsChanged, [])
        #expect(recorder.events == [.pressed, .cancelled])
    }

    @Test func noModifiersNeverOpens() {
        let recorder = Recorder([])
        #expect(!recorder.send(.flagsChanged, []))
        #expect(!recorder.send(.leftMouseDown, []))
        #expect(recorder.events.isEmpty)
    }

    @MainActor
    @Test func eventsReachTheModuleOnlyAfterTheTapCallbackReturns() async throws {
        let inbox = Inbox()
        let swallow = ModifierTrigger.swallow(Self.chord) { inbox.events.append($0) }
        let event = try #require(CGEvent(source: nil))
        event.flags = Self.held

        #expect(!swallow(.flagsChanged, event))
        #expect(inbox.events.isEmpty)
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        #expect(inbox.events == [.pressed])
    }

    @MainActor
    @Test(.enabled(if: AXIsProcessTrusted(), "Active event taps need Accessibility"))
    func theTapLivesAsLongAsItsModule() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let manager = try ModuleManager(
            store: SettingsStore(url: dir.appending(path: "settings.json")))
        let module = RadialModule()
        try manager.register(module)
        try manager.startEnabledModules()
        #expect(
            manager.activeResources == [
                ActiveResource(module: "radial", kind: .eventTap, name: "trigger")
            ])

        try manager.setEnabled("radial", false)
        #expect(manager.activeResources.isEmpty)
        #expect(module.stops == 1)
        #expect(module.events.isEmpty)
    }
}
