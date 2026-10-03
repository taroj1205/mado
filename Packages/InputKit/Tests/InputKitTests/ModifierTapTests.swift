import Carbon.HIToolbox
import CoreGraphics
import Dispatch
import Testing

@testable import InputKit

@Suite struct ModifierTapTests {
    typealias Tap = ModifierTap.Tap

    struct Recorder {
        static let singles = Set(ModifierTap.Key.allCases.map(Tap.single))

        var detector: ModifierTap
        var held: CGEventFlags = []
        var now: CGEventTimestamp = 1_000_000_000
        var taps: [Tap] = []

        init() {
            self.init(bindings: Self.singles, window: ModifierTap.defaultWindow)
        }

        init(bindings: Set<Tap>) {
            self.init(bindings: bindings, window: ModifierTap.defaultWindow)
        }

        init(bindings: Set<Tap>, window: Duration) {
            detector = ModifierTap(window: window, bindings: bindings)
        }

        mutating func tap(_ key: ModifierTap.Key) {
            down(key)
            wait(.milliseconds(50))
            up(key)
            wait(.milliseconds(80))
        }

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
            if let fired = detector.handle(type, flags: held, keyCode: keyCode, timestamp: now) {
                taps.append(fired)
            }
        }

        mutating func expire() {
            guard let deadline = detector.deadline else { return }
            if let fired = detector.expire(at: deadline) {
                taps.append(fired)
            }
        }
    }

    @MainActor
    final class Inbox {
        var taps: [Tap] = []
    }

    static func rightShift() throws -> (press: CGEvent, release: CGEvent) {
        let press = try #require(
            CGEvent(
                keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_RightShift), keyDown: true))
        press.flags = [
            .maskShift, .maskNonCoalesced, CGEventFlags(rawValue: ModifierTap.Key.rightShift.flag),
        ]
        press.timestamp = 1_000_000_000
        let release = try #require(press.copy())
        release.flags = .maskNonCoalesced
        release.timestamp = press.timestamp + 50_000_000
        return (press, release)
    }

    @Test(arguments: ModifierTap.Key.allCases)
    func aLoneQuickPressIsATapOfThatSide(_ key: ModifierTap.Key) {
        var recorder = Recorder()
        recorder.down(key)
        recorder.wait(.milliseconds(80))
        recorder.up(key)
        #expect(recorder.taps == [.single(key)])
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
        #expect(recorder.taps == [.single(.rightCommand)])
    }

    @Test func theWindowIsAdjustable() {
        var recorder = Recorder(bindings: Recorder.singles, window: .milliseconds(500))
        recorder.down(.leftControl)
        recorder.wait(.milliseconds(450))
        recorder.up(.leftControl)
        #expect(recorder.taps == [.single(.leftControl)])
    }

    @Test func aTapAfterAShortcutStillCounts() {
        var recorder = Recorder()
        recorder.down(.leftCommand)
        recorder.send(.keyDown)
        recorder.up(.leftCommand)
        recorder.down(.leftCommand)
        recorder.up(.leftCommand)
        #expect(recorder.taps == [.single(.leftCommand)])
    }

    @MainActor
    @Test func tapsArriveOnlyAfterTheCallbackReturns() async throws {
        let inbox = Inbox()
        let observe = ModifierTap.observe(
            window: ModifierTap.defaultWindow,
            bindings: [.single(.rightShift): { inbox.taps.append(.single(.rightShift)) }])
        let event = try Self.rightShift()
        observe(.flagsChanged, event.press)
        observe(.flagsChanged, event.release)
        #expect(inbox.taps.isEmpty)
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        #expect(inbox.taps == [.single(.rightShift)])
    }
}
