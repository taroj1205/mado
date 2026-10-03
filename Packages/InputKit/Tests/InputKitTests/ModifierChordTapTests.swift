import CoreGraphics
import Testing

@testable import InputKit

@Suite struct ModifierChordTapTests {
    typealias Recorder = ModifierTapTests.Recorder
    typealias Tap = ModifierTap.Tap

    static let shifts = Tap.together([.leftShift, .rightShift])

    @Test func twoModifiersTappedTogetherFireOnTheLastRelease() {
        var recorder = Recorder(bindings: [Self.shifts])
        recorder.down(.leftShift)
        recorder.down(.rightShift)
        recorder.wait(.milliseconds(50))
        recorder.up(.leftShift)
        #expect(recorder.taps.isEmpty)
        recorder.up(.rightShift)
        #expect(recorder.taps == [Self.shifts])
    }

    @Test func theOrderOfPressesAndReleasesDoesNotMatter() {
        var recorder = Recorder(bindings: [Self.shifts])
        recorder.down(.rightShift)
        recorder.down(.leftShift)
        recorder.up(.rightShift)
        recorder.up(.leftShift)
        #expect(recorder.taps == [Self.shifts])
    }

    @Test(arguments: [CGEventType.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown])
    func aShortcutOrClickWithBothHeldIsNotATap(_ type: CGEventType) {
        let commandShift = Tap.together([.leftCommand, .leftShift])
        var recorder = Recorder(bindings: [commandShift, .single(.leftCommand)])
        recorder.down(.leftCommand)
        recorder.down(.leftShift)
        recorder.send(type)
        recorder.up(.leftShift)
        recorder.up(.leftCommand)
        #expect(recorder.taps.isEmpty)
    }

    @Test func threeModifiersAreNotATap() {
        var recorder = Recorder(bindings: [Self.shifts])
        recorder.down(.leftShift)
        recorder.down(.rightShift)
        recorder.down(.leftOption)
        recorder.up(.leftOption)
        recorder.up(.rightShift)
        recorder.up(.leftShift)
        #expect(recorder.taps.isEmpty)
    }

    @Test func pressingAKeyAgainBeforeTheLastReleaseIsNotATap() {
        var recorder = Recorder(bindings: [Self.shifts])
        recorder.down(.leftShift)
        recorder.down(.rightShift)
        recorder.up(.rightShift)
        recorder.down(.rightShift)
        recorder.up(.rightShift)
        recorder.up(.leftShift)
        #expect(recorder.taps.isEmpty)
    }

    @Test func holdingPastTheWindowIsNotATap() {
        var recorder = Recorder(bindings: [Self.shifts])
        recorder.down(.leftShift)
        recorder.down(.rightShift)
        recorder.wait(ModifierTap.defaultWindow + .nanoseconds(1))
        recorder.up(.rightShift)
        recorder.up(.leftShift)
        #expect(recorder.taps.isEmpty)
    }

    @Test func anUnboundPairFiresNothing() {
        var recorder = Recorder()
        recorder.down(.leftShift)
        recorder.down(.rightShift)
        recorder.up(.rightShift)
        recorder.up(.leftShift)
        #expect(recorder.taps.isEmpty)
    }

    @Test func aPairEndsAWaitingTapAndSingleTapsWorkAfterIt() {
        var recorder = Recorder(bindings: [.single(.leftShift), .double(.leftShift), Self.shifts])
        recorder.tap(.leftShift)
        recorder.down(.leftShift)
        #expect(recorder.taps.isEmpty)
        recorder.down(.rightShift)
        #expect(recorder.taps == [.single(.leftShift)])
        recorder.up(.leftShift)
        recorder.up(.rightShift)
        recorder.tap(.leftShift)
        recorder.expire()
        #expect(recorder.taps == [.single(.leftShift), Self.shifts, .single(.leftShift)])
    }
}
