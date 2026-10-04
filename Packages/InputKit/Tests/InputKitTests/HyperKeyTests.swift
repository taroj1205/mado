import Carbon.HIToolbox
import CoreGraphics
import Testing

@testable import InputKit

@Suite struct HyperKeyTests {
    struct Recorder {
        var key: HyperKey
        var now: CGEventTimestamp = 1_000_000_000
        var isHeld = false

        init(isTapped: Bool) {
            key = HyperKey(isTapped: isTapped, window: ModifierTap.defaultWindow)
        }

        mutating func press() -> HyperKey.Action {
            isHeld = true
            return send(.keyDown, keyCode: HyperKey.keyCode, isRepeat: false)
        }

        mutating func repeatPress() -> HyperKey.Action {
            send(.keyDown, keyCode: HyperKey.keyCode, isRepeat: true)
        }

        mutating func release() -> HyperKey.Action {
            isHeld = false
            return send(.keyUp, keyCode: HyperKey.keyCode, isRepeat: false)
        }

        mutating func wait(_ duration: Duration) {
            now += CGEventTimestamp(duration / .nanoseconds(1))
        }

        mutating func send(_ type: CGEventType) -> HyperKey.Action {
            send(type, keyCode: Int64(kVK_ANSI_T), isRepeat: false)
        }

        mutating func send(_ type: CGEventType, keyCode: Int64, isRepeat: Bool) -> HyperKey.Action {
            let held = isHeld
            return key.handle(type, keyCode: keyCode, isRepeat: isRepeat, timestamp: now) { held }
        }
    }

    @MainActor
    final class Taps {
        var fired = 0
        var runs: [Task<Void, Never>] = []

        func swallow() -> @MainActor (CGEventType, CGEvent) -> Bool {
            HyperKey.swallow(
                { [weak self] _ in self?.fired += 1 },
                run: { [weak self] tap in self?.runs.append(Task { await tap() }) })
        }

        func settle() async {
            for run in runs {
                await run.value
            }
        }
    }

    private static func hyper(down isDown: Bool) throws -> CGEvent {
        try #require(
            CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_F18), keyDown: isDown))
    }

    @Test func theHyperKeyItselfNeverReachesApps() {
        var recorder = Recorder(isTapped: false)
        #expect(recorder.press() == .swallow)
        #expect(recorder.repeatPress() == .swallow)
        #expect(recorder.release() == .swallow)
    }

    @Test func keysPressedWhileHeldGetAllFourModifiers() {
        var recorder = Recorder(isTapped: true)
        _ = recorder.press()
        #expect(recorder.send(.keyDown) == .addModifiers)
        #expect(recorder.send(.keyUp) == .pass)
        #expect(recorder.release() == .swallow)
        #expect(recorder.send(.keyDown) == .pass)
    }

    @Test func aQuickTapRunsTheTapActionWhenOneIsChosen() {
        var recorder = Recorder(isTapped: true)
        _ = recorder.press()
        recorder.wait(.milliseconds(120))
        #expect(recorder.release() == .tap)
    }

    @Test func aQuickTapDoesNothingWhenNoActionIsChosen() {
        var recorder = Recorder(isTapped: false)
        _ = recorder.press()
        recorder.wait(.milliseconds(120))
        #expect(recorder.release() == .swallow)
    }

    @Test func aLongHoldIsNotATap() {
        var recorder = Recorder(isTapped: true)
        _ = recorder.press()
        recorder.wait(.milliseconds(200))
        _ = recorder.repeatPress()
        recorder.wait(.milliseconds(200))
        #expect(recorder.release() == .swallow)
    }

    @Test(arguments: [CGEventType.keyDown, .flagsChanged, .leftMouseDown])
    func usingTheHyperKeyIsNotATap(_ type: CGEventType) {
        var recorder = Recorder(isTapped: true)
        _ = recorder.press()
        _ = recorder.send(type)
        #expect(recorder.release() == .swallow)
    }

    @Test func aLostReleaseDoesNotLeaveTheModifiersOn() {
        var recorder = Recorder(isTapped: true)
        _ = recorder.press()
        recorder.isHeld = false
        #expect(recorder.send(.keyDown) == .pass)
        recorder.isHeld = true
        #expect(recorder.send(.keyDown) == .pass)
    }

    @MainActor
    @Test func keysMadoPostsForATapDoNotCountAsUsingTheHyperKey() async throws {
        let taps = Taps()
        let swallow = taps.swallow()
        let posted = try #require(
            CapsLockTap.keyStrokes(CGKeyCode(kVK_ANSI_T), flags: .maskCommand).first)
        #expect(swallow(.keyDown, try Self.hyper(down: true)))
        #expect(!swallow(.keyDown, posted))
        #expect(posted.flags == .maskCommand)
        #expect(swallow(.keyUp, try Self.hyper(down: false)))
        #expect(taps.fired == 0)
        await taps.settle()
        #expect(taps.fired == 1)
    }

    @MainActor
    @Test func aTapThatAPauseCancelsDoesNothing() async throws {
        let taps = Taps()
        let swallow = taps.swallow()
        #expect(swallow(.keyDown, try Self.hyper(down: true)))
        #expect(swallow(.keyUp, try Self.hyper(down: false)))
        #expect(taps.runs.count == 1)
        for run in taps.runs {
            run.cancel()
        }
        await taps.settle()
        #expect(taps.fired == 0)
    }
}
