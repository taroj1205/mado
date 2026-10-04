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
    @Test func keysMadoPostsForATapDoNotCountAsUsingTheHyperKey() throws {
        var taps = 0
        let swallow = HyperKey.swallow { _ in taps += 1 }
        let hyperDown = try #require(
            CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_F18), keyDown: true))
        let hyperUp = try #require(
            CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_F18), keyDown: false))
        let posted = try #require(
            CapsLockTap.keyStrokes(CGKeyCode(kVK_ANSI_T), flags: .maskCommand).first)
        #expect(swallow(.keyDown, hyperDown))
        #expect(!swallow(.keyDown, posted))
        #expect(posted.flags == .maskCommand)
        #expect(swallow(.keyUp, hyperUp))
        #expect(taps == 1)
    }
}
