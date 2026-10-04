import Carbon.HIToolbox
import CoreGraphics
import Dispatch
import Testing

@testable import InputKit

@Suite struct PushToTalkTests {
    struct Recorder {
        var talk = PushToTalk(key: .rightOption, window: ModifierTap.defaultWindow)
        var held: CGEventFlags = []
        var now: CGEventTimestamp = 1_000_000_000
        var isActive = false
        var events: [PushToTalk.Event] = []

        mutating func down(_ key: ModifierTap.Key) {
            held.insert(CGEventFlags(rawValue: key.flag))
            send(.flagsChanged, keyCode: key.keyCode)
        }

        mutating func up(_ key: ModifierTap.Key) {
            held.remove(CGEventFlags(rawValue: key.flag))
            send(.flagsChanged, keyCode: key.keyCode)
        }

        mutating func tap() {
            tap(.rightOption)
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
            send(type, keyCode: Int64(kVK_ANSI_C))
        }

        mutating func send(_ type: CGEventType, keyCode: Int64) {
            guard
                let event = talk.handle(
                    type, flags: held, keyCode: keyCode, timestamp: now, isActive: isActive)
            else { return }
            events.append(event)
            switch event {
            case .started: isActive = true
            case .toggled: break
            case .stopped, .cancelled: isActive = false
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
        #expect(recorder.events == [.started])
        recorder.wait(.seconds(3))
        recorder.up(.rightOption)
        #expect(recorder.events == [.started, .stopped])
    }

    @Test func aTapKeepsRecordingUntilTheNextPress() {
        var recorder = Recorder()
        recorder.tap()
        #expect(recorder.events == [.started, .toggled])
        recorder.wait(.seconds(5))
        recorder.down(.rightOption)
        #expect(recorder.events == [.started, .toggled, .stopped])
        recorder.up(.rightOption)
        #expect(recorder.events == [.started, .toggled, .stopped])
    }

    @Test func typingWhileToggledOnKeepsRecording() {
        var recorder = Recorder()
        recorder.tap()
        recorder.down(.leftCommand)
        recorder.send(.keyDown)
        recorder.up(.leftCommand)
        recorder.send(.leftMouseDown)
        #expect(recorder.events == [.started, .toggled])
        recorder.down(.leftShift)
        recorder.down(.rightOption)
        #expect(recorder.events == [.started, .toggled, .stopped])
    }

    @Test func aPressAtTheEdgeOfTheWindowStillToggles() {
        var recorder = Recorder()
        recorder.down(.rightOption)
        recorder.wait(ModifierTap.defaultWindow)
        recorder.up(.rightOption)
        #expect(recorder.events == [.started, .toggled])
        recorder.tap()
        recorder.down(.rightOption)
        recorder.wait(ModifierTap.defaultWindow + .nanoseconds(1))
        recorder.up(.rightOption)
        #expect(recorder.events == [.started, .toggled, .stopped, .started, .stopped])
    }

    @Test(arguments: [CGEventType.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown])
    func aShortcutWithTheKeyCancelsTheRecording(_ type: CGEventType) {
        var recorder = Recorder()
        recorder.down(.rightOption)
        recorder.send(type)
        recorder.up(.rightOption)
        #expect(recorder.events == [.started, .cancelled])
    }

    @Test func addingAnotherModifierCancelsTheRecording() {
        var recorder = Recorder()
        recorder.down(.rightOption)
        recorder.down(.leftCommand)
        recorder.up(.leftCommand)
        recorder.up(.rightOption)
        #expect(recorder.events == [.started, .cancelled])
    }

    @Test func capsLockWhileHeldKeepsRecording() {
        var recorder = Recorder()
        recorder.down(.rightOption)
        recorder.held.insert(.maskAlphaShift)
        recorder.send(.flagsChanged, keyCode: Int64(kVK_CapsLock))
        recorder.wait(.seconds(1))
        recorder.up(.rightOption)
        #expect(recorder.events == [.started, .stopped])
    }

    @Test func theKeyPressedWithAnotherModifierDoesNothing() {
        var recorder = Recorder()
        recorder.down(.leftShift)
        recorder.down(.rightOption)
        recorder.up(.rightOption)
        recorder.up(.leftShift)
        recorder.tap(.leftOption)
        recorder.tap(.rightCommand)
        #expect(recorder.events.isEmpty)
    }

    @Test func aPressAfterARecordingEndedOnItsOwnStartsAgain() {
        var recorder = Recorder()
        recorder.tap()
        recorder.isActive = false
        recorder.down(.rightOption)
        #expect(recorder.events == [.started, .toggled, .started])
    }

    @Test func aMissedReleaseEndsTheHoldAtTheNextModifierChange() {
        var recorder = Recorder()
        recorder.down(.rightOption)
        recorder.wait(.seconds(2))
        recorder.held = []
        recorder.send(.flagsChanged, keyCode: Int64(kVK_Shift))
        #expect(recorder.events == [.started, .stopped])
    }

    @MainActor
    @Test func eventsArriveOnlyAfterTheCallbackReturns() async throws {
        let inbox = Inbox()
        let observe = PushToTalk.observe(
            .rightOption, window: ModifierTap.defaultWindow, isActive: { false },
            onEvent: { inbox.events.append($0) })
        let event = try #require(
            CGEvent(
                keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_RightOption), keyDown: true))
        event.flags = [
            .maskAlternate, CGEventFlags(rawValue: ModifierTap.Key.rightOption.flag),
        ]
        observe(.flagsChanged, event)
        #expect(inbox.events.isEmpty)
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        #expect(inbox.events == [.started])
    }
}
