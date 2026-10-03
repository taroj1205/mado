import Carbon.HIToolbox
import CoreGraphics
import Testing

@testable import InputKit

@Suite struct ModifierMultiTapTests {
    typealias Inbox = ModifierTapTests.Inbox
    typealias Recorder = ModifierTapTests.Recorder
    typealias Tap = ModifierTap.Tap

    @Test func twoTapsInsideTheWindowAreADoubleTap() {
        var recorder = Recorder(bindings: [.double(.leftShift)])
        recorder.tap(.leftShift)
        #expect(recorder.taps.isEmpty)
        recorder.tap(.leftShift)
        #expect(recorder.taps == [.double(.leftShift)])
    }

    @Test func threeTapsInsideTheWindowAreATripleTap() {
        var recorder = Recorder(bindings: [.triple(.rightCommand)])
        recorder.tap(.rightCommand)
        recorder.tap(.rightCommand)
        #expect(recorder.taps.isEmpty)
        recorder.tap(.rightCommand)
        #expect(recorder.taps == [.triple(.rightCommand)])
    }

    @Test func countingStartsOverAfterATapFires() {
        var recorder = Recorder(bindings: [.double(.leftOption)])
        for _ in 1...4 {
            recorder.tap(.leftOption)
        }
        #expect(recorder.taps == [.double(.leftOption), .double(.leftOption)])
    }

    @Test func aSingleTapWithoutADoubleBindingIsNotDelayed() {
        var recorder = Recorder(bindings: [.single(.leftShift), .triple(.leftShift)])
        recorder.down(.leftShift)
        recorder.up(.leftShift)
        #expect(recorder.taps == [.single(.leftShift)])
        #expect(recorder.detector.deadline == nil)
    }

    @Test func aSingleTapWaitsOutTheWindowWhenADoubleIsBound() {
        var recorder = Recorder(bindings: [.single(.leftShift), .double(.leftShift)])
        recorder.tap(.leftShift)
        #expect(recorder.taps.isEmpty)
        recorder.expire()
        #expect(recorder.taps == [.single(.leftShift)])
    }

    @Test func aDoubleTapReplacesTheWaitingSingleTap() {
        var recorder = Recorder(bindings: [.single(.leftShift), .double(.leftShift)])
        recorder.tap(.leftShift)
        recorder.tap(.leftShift)
        recorder.expire()
        #expect(recorder.taps == [.double(.leftShift)])
    }

    @Test func aDoubleTapWaitsOutTheWindowWhenATripleIsBound() {
        var recorder = Recorder(bindings: [.double(.rightShift), .triple(.rightShift)])
        recorder.tap(.rightShift)
        recorder.tap(.rightShift)
        #expect(recorder.taps.isEmpty)
        recorder.expire()
        #expect(recorder.taps == [.double(.rightShift)])
    }

    @Test func theWindowStartsAgainWhenTheNextTapBegins() throws {
        var recorder = Recorder(bindings: [.single(.leftShift), .double(.leftShift)])
        recorder.tap(.leftShift)
        let first = try #require(recorder.detector.deadline)
        recorder.down(.leftShift)
        #expect(recorder.detector.expire(at: first) == nil)
        recorder.up(.leftShift)
        #expect(recorder.taps == [.double(.leftShift)])
    }

    @Test func aSecondPressHeldPastTheWindowFiresTheFirstTapWhileStillHeld() {
        var recorder = Recorder(bindings: [.single(.leftShift), .double(.leftShift)])
        recorder.tap(.leftShift)
        recorder.down(.leftShift)
        recorder.wait(ModifierTap.defaultWindow)
        recorder.expire()
        #expect(recorder.taps == [.single(.leftShift)])
        recorder.up(.leftShift)
        #expect(recorder.taps == [.single(.leftShift)])
    }

    @Test func aGapLongerThanTheWindowStartsANewCount() {
        var recorder = Recorder(bindings: [.single(.leftShift), .double(.leftShift)])
        recorder.down(.leftShift)
        recorder.up(.leftShift)
        recorder.wait(ModifierTap.defaultWindow + .nanoseconds(1))
        recorder.down(.leftShift)
        #expect(recorder.taps == [.single(.leftShift)])
        recorder.up(.leftShift)
        recorder.expire()
        #expect(recorder.taps == [.single(.leftShift), .single(.leftShift)])
    }

    @Test func anotherKeyFiresTheWaitingTapAtOnce() {
        var recorder = Recorder(bindings: [.single(.leftShift), .double(.leftShift)])
        recorder.tap(.leftShift)
        recorder.send(.keyDown)
        #expect(recorder.taps == [.single(.leftShift)])
        #expect(recorder.detector.deadline == nil)
    }

    @Test func aShortcutOnTheSecondPressFiresTheFirstTap() {
        var recorder = Recorder(bindings: [.single(.leftShift), .double(.leftShift)])
        recorder.tap(.leftShift)
        recorder.down(.leftShift)
        recorder.send(.keyDown)
        recorder.up(.leftShift)
        #expect(recorder.taps == [.single(.leftShift)])
    }

    @Test func aHeldSecondPressFiresTheFirstTap() {
        var recorder = Recorder(bindings: [.single(.leftShift), .double(.leftShift)])
        recorder.tap(.leftShift)
        recorder.down(.leftShift)
        recorder.wait(ModifierTap.defaultWindow + .nanoseconds(1))
        recorder.up(.leftShift)
        #expect(recorder.taps == [.single(.leftShift)])
    }

    @Test func tapsOfDifferentKeysDoNotCountTogether() {
        var recorder = Recorder(bindings: [.single(.leftShift), .double(.leftShift)])
        recorder.tap(.leftShift)
        recorder.tap(.rightShift)
        recorder.tap(.leftShift)
        recorder.expire()
        #expect(recorder.taps == [.single(.leftShift), .single(.leftShift)])
    }

    @Test func anExpiryForAnEarlierTapIsIgnored() throws {
        var recorder = Recorder(bindings: [.double(.leftShift), .triple(.leftShift)])
        recorder.tap(.leftShift)
        recorder.tap(.leftShift)
        let deadline = try #require(recorder.detector.deadline)
        #expect(recorder.detector.expire(at: deadline - 1) == nil)
        #expect(recorder.detector.expire(at: deadline) == .double(.leftShift))
    }

    @MainActor
    @Test func aWaitingTapFiresOnceTheWindowPasses() async throws {
        let inbox = Inbox()
        let observe = ModifierTap.observe(
            window: .milliseconds(100),
            bindings: [
                .single(.rightShift): { inbox.taps.append(.single(.rightShift)) },
                .double(.rightShift): { inbox.taps.append(.double(.rightShift)) },
            ])
        let event = try ModifierTapTests.rightShift()
        observe(.flagsChanged, event.press)
        observe(.flagsChanged, event.release)
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        #expect(inbox.taps.isEmpty)
        try await Task.sleep(for: .milliseconds(300))
        withExtendedLifetime(observe) {
            #expect(inbox.taps == [.single(.rightShift)])
        }
    }

    @MainActor
    @Test func aWaitingTapIsDroppedWhenTheObserverIsRemoved() async throws {
        let inbox = Inbox()
        var observe: (@MainActor (CGEventType, CGEvent) -> Void)? = ModifierTap.observe(
            window: .milliseconds(100),
            bindings: [
                .single(.rightShift): { inbox.taps.append(.single(.rightShift)) },
                .double(.rightShift): { inbox.taps.append(.double(.rightShift)) },
            ])
        let event = try ModifierTapTests.rightShift()
        observe?(.flagsChanged, event.press)
        observe?(.flagsChanged, event.release)
        observe = nil
        try await Task.sleep(for: .milliseconds(300))
        #expect(inbox.taps.isEmpty)
    }
}
