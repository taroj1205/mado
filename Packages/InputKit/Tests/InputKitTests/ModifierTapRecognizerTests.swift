import CoreGraphics
import Dispatch
import Testing

@testable import InputKit

@MainActor
@Suite struct ModifierTapRecognizerTests {
    @MainActor
    final class Inbox {
        var taps: [ModifierTap.Tap] = []
        var waits: [Task<Void, Never>] = []

        func recognizer(
            window: Duration, bound: Set<ModifierTap.Tap>
        ) -> ModifierTap.Recognizer {
            let bindings = Dictionary(
                uniqueKeysWithValues: bound.map { tap -> (ModifierTap.Tap, @MainActor () -> Void) in
                    (tap, { [weak self] in self?.taps.append(tap) })
                })
            return ModifierTap.Recognizer(window: window, bindings: bindings) { [weak self] wait in
                self?.waits.append(Task { await wait() })
            }
        }

        func settle() async {
            for wait in waits {
                await wait.value
            }
            await withCheckedContinuation { continuation in
                DispatchQueue.main.async { continuation.resume() }
            }
        }
    }

    static func tap(
        _ key: ModifierTap.Key, at time: CGEventTimestamp, into recognizer: ModifierTap.Recognizer
    ) throws {
        let event = try #require(
            CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(key.keyCode), keyDown: true))
        event.flags = [.maskNonCoalesced, CGEventFlags(rawValue: key.flag)]
        event.timestamp = time
        recognizer.handle(.flagsChanged, event)
        event.flags = .maskNonCoalesced
        event.timestamp = time + 10_000_000
        recognizer.handle(.flagsChanged, event)
    }

    @Test func aSingleWithoutADoubleArrivesWithoutWaiting() async throws {
        let inbox = Inbox()
        let recognizer = inbox.recognizer(
            window: ModifierTap.defaultWindow, bound: [ModifierTap.Tap(.rightShift)])
        try Self.tap(.rightShift, at: 1_000_000_000, into: recognizer)
        #expect(inbox.taps.isEmpty)
        #expect(inbox.waits.isEmpty)
        await inbox.settle()
        #expect(inbox.taps == [ModifierTap.Tap(.rightShift)])
    }

    @Test func aWaitingSingleArrivesWhenTheWindowRunsOut() async throws {
        let inbox = Inbox()
        let recognizer = inbox.recognizer(
            window: .milliseconds(20), bound: ModifierTapTests.shiftTaps)
        try Self.tap(.leftShift, at: 1_000_000_000, into: recognizer)
        #expect(inbox.waits.count == 1)
        await inbox.settle()
        #expect(inbox.taps == [ModifierTap.Tap(.leftShift)])
    }

    @Test func aDoubleCancelsTheWaitingSingle() async throws {
        let inbox = Inbox()
        let recognizer = inbox.recognizer(
            window: .milliseconds(100), bound: ModifierTapTests.shiftTaps)
        try Self.tap(.leftShift, at: 1_000_000_000, into: recognizer)
        try Self.tap(.leftShift, at: 1_080_000_000, into: recognizer)
        await inbox.settle()
        #expect(inbox.taps == [ModifierTap.Tap(.leftShift, count: 2)])
    }

    @Test func aWaitingSingleIsDroppedWhenItsWaitIsCancelled() async throws {
        let inbox = Inbox()
        let recognizer = inbox.recognizer(
            window: .milliseconds(20), bound: ModifierTapTests.shiftTaps)
        try Self.tap(.leftShift, at: 1_000_000_000, into: recognizer)
        for wait in inbox.waits {
            wait.cancel()
        }
        await inbox.settle()
        #expect(inbox.taps.isEmpty)
    }
}
