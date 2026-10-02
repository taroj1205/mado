import Carbon.HIToolbox
import CoreGraphics
import Dispatch
import Testing

@testable import InputKit

@Suite struct ModifierTapTests {
    struct Recorder {
        var tap = ModifierTap(window: ModifierTap.defaultWindow)
        var held: CGEventFlags = []
        var now: CGEventTimestamp = 1_000_000_000
        var taps: [ModifierTap.Key] = []

        mutating func down(_ key: ModifierTap.Key) {
            held.insert(CGEventFlags(rawValue: key.flag))
            send(.flagsChanged, keyCode: key.keyCode)
        }

        mutating func up(_ key: ModifierTap.Key) {
            held.remove(CGEventFlags(rawValue: key.flag))
            send(.flagsChanged, keyCode: key.keyCode)
        }

        mutating func wait(_ duration: Duration) {
            now += CGEventTimestamp(duration / .nanoseconds(1))
        }

        mutating func send(_ type: CGEventType) {
            send(type, keyCode: Int64(kVK_ANSI_C))
        }

        mutating func send(_ type: CGEventType, keyCode: Int64) {
            if let key = tap.handle(type, flags: held, keyCode: keyCode, timestamp: now) {
                taps.append(key)
            }
        }
    }

    @MainActor
    final class Inbox {
        var taps: [ModifierTap.Key] = []
    }

    @Test(arguments: ModifierTap.Key.allCases)
    func aLoneQuickPressIsATapOfThatSide(_ key: ModifierTap.Key) {
        var recorder = Recorder()
        recorder.down(key)
        recorder.wait(.milliseconds(80))
        recorder.up(key)
        #expect(recorder.taps == [key])
    }

    @Test func aShortcutIsNotATap() {
        var recorder = Recorder()
        recorder.down(.leftCommand)
        recorder.send(.keyDown)
        recorder.up(.leftCommand)
        #expect(recorder.taps.isEmpty)
    }

    @Test(arguments: [CGEventType.leftMouseDown, .rightMouseDown, .otherMouseDown])
    func aClickWhileHeldIsNotATap(_ type: CGEventType) {
        var recorder = Recorder()
        recorder.down(.leftOption)
        recorder.send(type)
        recorder.up(.leftOption)
        #expect(recorder.taps.isEmpty)
    }

    @Test func twoModifiersTogetherAreNotATap() {
        var recorder = Recorder()
        recorder.down(.leftShift)
        recorder.down(.leftCommand)
        recorder.up(.leftCommand)
        recorder.up(.leftShift)
        recorder.down(.leftCommand)
        recorder.down(.rightCommand)
        recorder.up(.rightCommand)
        recorder.up(.leftCommand)
        #expect(recorder.taps.isEmpty)
    }

    @Test func capsLockWhileHeldIsNotATap() {
        var recorder = Recorder()
        recorder.down(.leftShift)
        recorder.held.insert(.maskAlphaShift)
        recorder.send(.flagsChanged, keyCode: Int64(kVK_CapsLock))
        recorder.up(.leftShift)
        #expect(recorder.taps.isEmpty)
    }

    @Test func aPressLongerThanTheWindowIsNotATap() {
        var recorder = Recorder()
        recorder.down(.rightCommand)
        recorder.wait(ModifierTap.defaultWindow)
        recorder.up(.rightCommand)
        recorder.down(.rightCommand)
        recorder.wait(ModifierTap.defaultWindow + .nanoseconds(1))
        recorder.up(.rightCommand)
        #expect(recorder.taps == [.rightCommand])
    }

    @Test func theWindowIsAdjustable() {
        var recorder = Recorder(tap: ModifierTap(window: .milliseconds(500)))
        recorder.down(.leftControl)
        recorder.wait(.milliseconds(450))
        recorder.up(.leftControl)
        #expect(recorder.taps == [.leftControl])
    }

    @Test func aTapAfterAShortcutStillCounts() {
        var recorder = Recorder()
        recorder.down(.leftCommand)
        recorder.send(.keyDown)
        recorder.up(.leftCommand)
        recorder.down(.leftCommand)
        recorder.up(.leftCommand)
        #expect(recorder.taps == [.leftCommand])
    }

    @MainActor
    @Test func tapsArriveOnlyAfterTheCallbackReturns() async throws {
        let inbox = Inbox()
        let observe = ModifierTap.observe(window: ModifierTap.defaultWindow) { key in
            inbox.taps.append(key)
        }
        let event = try #require(
            CGEvent(
                keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_RightShift), keyDown: true))

        event.flags = [
            .maskShift, .maskNonCoalesced, CGEventFlags(rawValue: ModifierTap.Key.rightShift.flag),
        ]
        event.timestamp = 1_000_000_000
        observe(.flagsChanged, event)
        event.flags = .maskNonCoalesced
        event.timestamp += 50_000_000
        observe(.flagsChanged, event)
        #expect(inbox.taps.isEmpty)
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        #expect(inbox.taps == [.rightShift])
    }
}
