import AppCore
import Carbon.HIToolbox
import CoreGraphics
import Dispatch
import Testing

@testable import InputKit

@Suite struct ModifierTapTests {
    struct Recorder {
        var tap = ModifierTap(window: ModifierTap.defaultWindow, bound: [])
        var held: CGEventFlags = []
        var now: CGEventTimestamp = 1_000_000_000
        var taps: [ModifierTap.Tap] = []

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
            wait(.milliseconds(50))
            up(key)
            wait(.milliseconds(100))
        }

        mutating func wait(_ duration: Duration) {
            now += CGEventTimestamp(duration / .nanoseconds(1))
        }

        mutating func send(_ type: CGEventType) {
            send(type, keyCode: Int64(kVK_ANSI_C))
        }

        mutating func send(_ type: CGEventType, keyCode: Int64) {
            if let fired = tap.handle(type, flags: held, keyCode: keyCode, timestamp: now) {
                taps.append(fired)
            }
        }
    }

    static let shiftTaps: Set<ModifierTap.Tap> = [
        ModifierTap.Tap(.leftShift), ModifierTap.Tap(.leftShift, count: 2),
    ]

    static func recorder(_ bound: Set<ModifierTap.Tap>) -> Recorder {
        Recorder(tap: ModifierTap(window: ModifierTap.defaultWindow, bound: bound))
    }

    @Test(arguments: ModifierTap.Key.allCases)
    func aLoneQuickPressIsATapOfThatSide(_ key: ModifierTap.Key) {
        var recorder = Recorder()
        recorder.down(key)
        recorder.wait(.milliseconds(80))
        recorder.up(key)
        #expect(recorder.taps == [ModifierTap.Tap(key)])
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
        #expect(recorder.taps == [ModifierTap.Tap(.rightCommand)])
    }

    @Test func theWindowIsAdjustable() {
        var recorder = Recorder(tap: ModifierTap(window: .milliseconds(500), bound: []))
        recorder.down(.leftControl)
        recorder.wait(.milliseconds(450))
        recorder.up(.leftControl)
        #expect(recorder.taps == [ModifierTap.Tap(.leftControl)])
    }

    @Test func aTapAfterAShortcutStillCounts() {
        var recorder = Recorder()
        recorder.down(.leftCommand)
        recorder.send(.keyDown)
        recorder.up(.leftCommand)
        recorder.down(.leftCommand)
        recorder.up(.leftCommand)
        #expect(recorder.taps == [ModifierTap.Tap(.leftCommand)])
    }

    @Test func withoutALongerBindingEveryTapIsASingle() {
        var recorder = Self.recorder([ModifierTap.Tap(.leftCommand)])
        recorder.tap(.leftCommand)
        recorder.tap(.leftCommand)
        #expect(recorder.taps == [ModifierTap.Tap(.leftCommand), ModifierTap.Tap(.leftCommand)])
    }

    @Test func tapsInsideTheWindowCountUpToTheLongestBinding() {
        var recorder = Self.recorder([ModifierTap.Tap(.rightCommand, count: 3)])
        for _ in 1...4 {
            recorder.tap(.rightCommand)
        }
        #expect(recorder.taps.map(\.count) == [1, 2, 3, 1])
        #expect(recorder.taps.allSatisfy { $0.keys == [.rightCommand] })
    }

    @Test func aSingleWaitsOnlyWhenItsDoubleIsAlsoBound() {
        var recorder = Self.recorder(Self.shiftTaps.union([ModifierTap.Tap(.rightShift)]))
        recorder.tap(.rightShift)
        recorder.tap(.leftShift)
        #expect(recorder.taps == [ModifierTap.Tap(.rightShift)])
        #expect(recorder.tap.held == ModifierTap.Tap(.leftShift))
        #expect(recorder.tap.expire() == ModifierTap.Tap(.leftShift))
        #expect(recorder.tap.held == nil)
    }

    @Test func aDoubleReplacesTheWaitingSingle() {
        var recorder = Self.recorder(Self.shiftTaps)
        recorder.tap(.leftShift)
        recorder.tap(.leftShift)
        #expect(recorder.taps == [ModifierTap.Tap(.leftShift, count: 2)])
        #expect(recorder.tap.held == nil)
    }

    @Test func aDoubleWaitsWhenItsTripleIsAlsoBound() {
        let double = ModifierTap.Tap(.leftOption, count: 2)
        let triple = ModifierTap.Tap(.leftOption, count: 3)
        var recorder = Self.recorder([double, triple])
        recorder.tap(.leftOption)
        recorder.tap(.leftOption)
        #expect(recorder.taps == [ModifierTap.Tap(.leftOption)])
        #expect(recorder.tap.held == double)
        recorder.tap(.leftOption)
        #expect(recorder.taps == [ModifierTap.Tap(.leftOption), triple])
    }

    @Test func aGapLongerThanTheWindowStartsANewRun() {
        var recorder = Self.recorder(Self.shiftTaps)
        recorder.tap(.leftShift)
        recorder.wait(ModifierTap.defaultWindow)
        recorder.down(.leftShift)
        #expect(recorder.taps == [ModifierTap.Tap(.leftShift)])
        recorder.up(.leftShift)
        #expect(recorder.tap.held == ModifierTap.Tap(.leftShift))
    }

    @Test(arguments: [CGEventType.keyDown, .leftMouseDown])
    func anotherInputReleasesTheWaitingSingleAndEndsTheRun(_ type: CGEventType) {
        var recorder = Self.recorder(Self.shiftTaps)
        recorder.tap(.leftShift)
        recorder.send(type)
        #expect(recorder.taps == [ModifierTap.Tap(.leftShift)])
        recorder.tap(.leftShift)
        #expect(recorder.taps == [ModifierTap.Tap(.leftShift)])
        #expect(recorder.tap.held == ModifierTap.Tap(.leftShift))
    }

    @Test func anotherModifierReleasesTheWaitingSingle() {
        var recorder = Self.recorder(Self.shiftTaps)
        recorder.tap(.leftShift)
        recorder.down(.rightShift)
        #expect(recorder.taps == [ModifierTap.Tap(.leftShift)])
    }

    @Test func theWaitingSingleStaysWhileTheNextPressIsDown() {
        var recorder = Self.recorder(Self.shiftTaps)
        recorder.tap(.leftShift)
        recorder.down(.leftShift)
        #expect(recorder.tap.expire() == nil)
        recorder.wait(.milliseconds(50))
        recorder.up(.leftShift)
        #expect(recorder.taps == [ModifierTap.Tap(.leftShift, count: 2)])
    }

    @Test func aLongSecondPressReleasesTheWaitingSingle() {
        var recorder = Self.recorder(Self.shiftTaps)
        recorder.tap(.leftShift)
        recorder.down(.leftShift)
        recorder.wait(ModifierTap.defaultWindow + .nanoseconds(1))
        recorder.up(.leftShift)
        #expect(recorder.taps == [ModifierTap.Tap(.leftShift)])
        #expect(recorder.tap.held == nil)
    }

    @Test func aRecordedModifierTapKeepsItsSide() {
        let pairs: [(HotKey.ModifierKey, ModifierTap.Key)] = [
            (.leftCommand, .leftCommand), (.rightCommand, .rightCommand),
            (.leftOption, .leftOption), (.rightOption, .rightOption),
            (.leftControl, .leftControl), (.rightControl, .rightControl),
            (.leftShift, .leftShift), (.rightShift, .rightShift),
        ]
        for (recorded, key) in pairs {
            #expect(ModifierTap.Tap(recorded) == ModifierTap.Tap(key, count: 1))
        }
    }
}
