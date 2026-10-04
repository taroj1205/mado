import Carbon.HIToolbox
import CoreGraphics
import Testing

@testable import InputKit

@Suite struct ModifierChordTapTests {
    typealias Recorder = ModifierTapTests.Recorder

    static let shifts = ModifierTap.Tap(.leftShift, .rightShift)

    @Test func twoModifiersPressedTogetherAndReleasedAreAChordTap() {
        var recorder = Recorder()
        recorder.down(.leftShift)
        recorder.down(.rightShift)
        recorder.wait(.milliseconds(80))
        recorder.up(.leftShift)
        #expect(recorder.taps.isEmpty)
        recorder.up(.rightShift)
        #expect(recorder.taps == [Self.shifts])
    }

    @Test func theOrderOfPressAndReleaseDoesNotMatter() {
        var recorder = Recorder()
        recorder.down(.rightCommand)
        recorder.down(.leftShift)
        recorder.up(.rightCommand)
        recorder.up(.leftShift)
        #expect(recorder.taps == [ModifierTap.Tap(.leftShift, .rightCommand)])
        #expect(ModifierTap.Tap(.rightShift, .leftShift) == Self.shifts)
    }

    @Test(arguments: [
        (CGEventType.keyDown, Int64(kVK_ANSI_C)), (.leftMouseDown, Int64(kVK_ANSI_C)),
        (.flagsChanged, Int64(kVK_CapsLock)),
    ])
    func anotherInputWhileHeldIsNotAChordTap(_ type: CGEventType, _ keyCode: Int64) {
        var recorder = Recorder()
        recorder.down(.leftCommand)
        recorder.down(.leftShift)
        recorder.send(type, keyCode: keyCode)
        recorder.up(.leftShift)
        recorder.up(.leftCommand)
        recorder.down(.leftCommand)
        recorder.down(.leftShift)
        recorder.up(.leftShift)
        recorder.send(type, keyCode: keyCode)
        recorder.up(.leftCommand)
        #expect(recorder.taps.isEmpty)
    }

    @Test func threeModifiersAreNotAChordTap() {
        var recorder = Recorder()
        recorder.down(.leftCommand)
        recorder.down(.leftShift)
        recorder.down(.leftOption)
        recorder.up(.leftOption)
        recorder.up(.leftShift)
        recorder.up(.leftCommand)
        #expect(recorder.taps.isEmpty)
    }

    @Test func pressingAKeyOfTheChordAgainIsNotAChordTap() {
        var recorder = Recorder()
        recorder.down(.leftShift)
        recorder.down(.rightShift)
        recorder.up(.rightShift)
        recorder.down(.rightShift)
        recorder.up(.rightShift)
        recorder.up(.leftShift)
        #expect(recorder.taps.isEmpty)
    }

    @Test func aChordLongerThanTheWindowIsNotATap() {
        var recorder = Recorder()
        recorder.down(.leftShift)
        recorder.down(.rightShift)
        recorder.wait(ModifierTap.defaultWindow)
        recorder.up(.rightShift)
        recorder.up(.leftShift)
        recorder.down(.leftShift)
        recorder.wait(.milliseconds(200))
        recorder.down(.rightShift)
        recorder.wait(.milliseconds(100) + .nanoseconds(1))
        recorder.up(.rightShift)
        recorder.up(.leftShift)
        #expect(recorder.taps == [Self.shifts])
    }

    @Test func aChordReleasesTheWaitingSingleAndIsNotADouble() {
        var recorder = ModifierTapTests.recorder(ModifierTapTests.shiftTaps)
        recorder.tap(.leftShift)
        recorder.down(.leftShift)
        recorder.down(.rightShift)
        #expect(recorder.taps == [ModifierTap.Tap(.leftShift)])
        recorder.up(.rightShift)
        recorder.up(.leftShift)
        #expect(recorder.taps == [ModifierTap.Tap(.leftShift), Self.shifts])
        #expect(recorder.tap.held == nil)
    }

    @MainActor
    @Test func aBoundChordTapRunsItsAction() async throws {
        let inbox = ModifierTapRecognizerTests.Inbox()
        let recognizer = inbox.recognizer(
            window: ModifierTap.defaultWindow, bound: [Self.shifts, ModifierTap.Tap(.leftShift)])
        let event = try #require(
            CGEvent(
                keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_Shift), keyDown: true))
        let left = CGEventFlags(rawValue: ModifierTap.Key.leftShift.flag)
        let right = CGEventFlags(rawValue: ModifierTap.Key.rightShift.flag)
        event.timestamp = 1_000_000_000
        event.flags = left
        recognizer.handle(.flagsChanged, event)
        event.setIntegerValueField(.keyboardEventKeycode, value: Int64(kVK_RightShift))
        event.flags = [left, right]
        recognizer.handle(.flagsChanged, event)
        event.flags = left
        recognizer.handle(.flagsChanged, event)
        event.setIntegerValueField(.keyboardEventKeycode, value: Int64(kVK_Shift))
        event.flags = []
        recognizer.handle(.flagsChanged, event)
        await inbox.settle()
        #expect(inbox.taps == [Self.shifts])
    }
}
