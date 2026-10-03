import Carbon.HIToolbox
import CoreGraphics
import Dispatch
import Testing

@testable import InputKit

@Suite struct PushToTalkTests {
    struct Recorder {
        var machine = PushToTalk(key: .rightOption, window: ModifierTap.defaultWindow)
        var held: CGEventFlags = []
        var now: CGEventTimestamp = 1_000_000_000
        var events: [PushToTalk.Event] = []

        mutating func down(_ key: ModifierTap.Key) {
            held.insert(CGEventFlags(rawValue: key.flag))
            send(.flagsChanged, keyCode: key.keyCode)
        }

        mutating func up(_ key: ModifierTap.Key) {
            held.remove(CGEventFlags(rawValue: key.flag))
            send(.flagsChanged, keyCode: key.keyCode)
        }

        mutating func tap(_ key: ModifierTap.Key) {
            down(key)
            wait(.milliseconds(80))
            up(key)
        }

        mutating func wait(_ duration: Duration) {
            now += CGEventTimestamp(duration / .nanoseconds(1))
        }

        mutating func send(_ type: CGEventType) {
            send(type, keyCode: Int64(kVK_ANSI_E))
        }

        mutating func send(_ type: CGEventType, keyCode: Int64) {
            if let event = machine.handle(type, flags: held, keyCode: keyCode, timestamp: now) {
                events.append(event)
            }
        }
    }

    @MainActor
    final class Inbox {
        var events: [PushToTalk.Event] = []
    }

    @Test func holdingTheKeyRecordsUntilItIsReleased() {
        var recorder = Recorder()
        recorder.down(.rightOption)
        #expect(recorder.events == [.start])
        recorder.wait(.seconds(2))
        recorder.up(.rightOption)
        #expect(recorder.events == [.start, .stop])
    }

    @Test func aTapKeepsRecordingUntilTheNextTap() {
        var recorder = Recorder()
        recorder.tap(.rightOption)
        #expect(recorder.events == [.start])
        recorder.wait(.seconds(5))
        recorder.send(.keyDown)
        recorder.send(.leftMouseDown)
        recorder.down(.rightOption)
        #expect(recorder.events == [.start, .stop])
        recorder.wait(.seconds(1))
        recorder.up(.rightOption)
        #expect(recorder.events == [.start, .stop])
    }

    @Test func aPressUpToTheWindowIsATapAndALongerOneIsAHold() {
        var recorder = Recorder()
        recorder.down(.rightOption)
        recorder.wait(ModifierTap.defaultWindow)
        recorder.up(.rightOption)
        recorder.down(.rightOption)
        #expect(recorder.events == [.start, .stop])
        recorder.up(.rightOption)
        recorder.down(.rightOption)
        recorder.wait(ModifierTap.defaultWindow + .nanoseconds(1))
        recorder.up(.rightOption)
        #expect(recorder.events == [.start, .stop, .start, .stop])
    }

    @Test(arguments: [CGEventType.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown])
    func aShortcutOrClickWhileHeldCancels(_ type: CGEventType) {
        var recorder = Recorder()
        recorder.down(.rightOption)
        recorder.send(type)
        recorder.wait(.seconds(1))
        recorder.up(.rightOption)
        #expect(recorder.events == [.start, .cancel])
        recorder.tap(.rightOption)
        #expect(recorder.events == [.start, .cancel, .start])
    }

    @Test func anotherModifierWhileHeldCancels() {
        var recorder = Recorder()
        recorder.down(.rightOption)
        recorder.down(.leftShift)
        recorder.up(.rightOption)
        #expect(recorder.events == [.start, .cancel])
        recorder.down(.rightOption)
        recorder.up(.rightOption)
        recorder.up(.leftShift)
        #expect(recorder.events == [.start, .cancel])
    }

    @Test func theKeyWithOtherModifiersOrTheOtherSideDoesNothing() {
        var recorder = Recorder()
        recorder.down(.leftCommand)
        recorder.down(.rightOption)
        recorder.up(.rightOption)
        recorder.up(.leftCommand)
        recorder.tap(.leftOption)
        #expect(recorder.events.isEmpty)
    }

    @Test func whileLatchedOnlyTheKeyAloneStops() {
        var recorder = Recorder()
        recorder.tap(.rightOption)
        recorder.down(.leftShift)
        recorder.down(.rightOption)
        recorder.up(.rightOption)
        recorder.up(.leftShift)
        #expect(recorder.events == [.start])
        recorder.tap(.rightOption)
        #expect(recorder.events == [.start, .stop])
    }

    @MainActor
    @Test func eventsArriveOnlyAfterTheCallbackReturns() async throws {
        let inbox = Inbox()
        let observe = PushToTalk.observe(.rightOption, window: ModifierTap.defaultWindow) { event in
            inbox.events.append(event)
        }
        let event = try #require(
            CGEvent(
                keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_RightOption), keyDown: true))
        event.flags = [
            .maskAlternate, .maskNonCoalesced,
            CGEventFlags(rawValue: ModifierTap.Key.rightOption.flag),
        ]
        event.timestamp = 1_000_000_000
        observe(.flagsChanged, event)
        #expect(inbox.events.isEmpty)
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        #expect(inbox.events == [.start])
    }
}
