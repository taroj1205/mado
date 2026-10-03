import Carbon.HIToolbox
import CoreGraphics
import Testing

@testable import InputKit

@Suite struct HyperKeyTests {
    struct Keyboard {
        var key: HyperKey
        var now: CGEventTimestamp = 1_000_000_000

        init(tapsEscape: Bool) {
            key = HyperKey(tapsEscape: tapsEscape)
        }

        mutating func wait(_ duration: Duration) {
            now += CGEventTimestamp(duration / .nanoseconds(1))
        }

        mutating func send(_ type: CGEventType) -> HyperKey.Outcome {
            send(type, HyperKey.keyCode)
        }

        mutating func send(_ type: CGEventType, _ keyCode: Int64) -> HyperKey.Outcome {
            key.handle(type, keyCode: keyCode, timestamp: now)
        }
    }

    private static let letter = Int64(kVK_ANSI_T)

    @Test func aQuickTapSendsEscape() {
        var keyboard = Keyboard(tapsEscape: true)
        #expect(keyboard.send(.keyDown) == .swallow)
        keyboard.wait(.milliseconds(80))
        #expect(keyboard.send(.keyUp) == .escape)
    }

    @Test func aTapSendsNothingWhenEscapeIsOff() {
        var keyboard = Keyboard(tapsEscape: false)
        _ = keyboard.send(.keyDown)
        #expect(keyboard.send(.keyUp) == .pass)
    }

    @Test func aLongPressIsNotATap() {
        var keyboard = Keyboard(tapsEscape: true)
        _ = keyboard.send(.keyDown)
        keyboard.wait(.milliseconds(400))
        #expect(keyboard.send(.keyUp) == .pass)
    }

    @Test func autoRepeatKeepsTheFirstPressTime() {
        var keyboard = Keyboard(tapsEscape: true)
        _ = keyboard.send(.keyDown)
        keyboard.wait(.milliseconds(250))
        #expect(keyboard.send(.keyDown) == .swallow)
        keyboard.wait(.milliseconds(100))
        #expect(keyboard.send(.keyUp) == .pass)
    }

    @Test func keysPressedWhileHeldGetHyper() {
        var keyboard = Keyboard(tapsEscape: true)
        _ = keyboard.send(.keyDown)
        #expect(keyboard.send(.keyDown, Self.letter) == .hyper)
        #expect(keyboard.send(.keyUp, Self.letter) == .hyper)
        #expect(keyboard.send(.keyUp) == .pass)
    }

    @Test(arguments: [CGEventType.flagsChanged, .leftMouseDown, .rightMouseDown, .otherMouseDown])
    func otherInputWhileHeldCancelsTheTap(_ type: CGEventType) {
        var keyboard = Keyboard(tapsEscape: true)
        _ = keyboard.send(.keyDown)
        #expect(keyboard.send(type, Int64(kVK_Shift)) == .pass)
        #expect(keyboard.send(.keyUp) == .pass)
    }

    @Test func keysPassUntouchedWhenNotHeld() {
        var keyboard = Keyboard(tapsEscape: true)
        #expect(keyboard.send(.keyDown, Self.letter) == .pass)
        _ = keyboard.send(.keyDown)
        _ = keyboard.send(.keyUp)
        #expect(keyboard.send(.keyUp, Self.letter) == .pass)
        #expect(keyboard.send(.flagsChanged, Int64(kVK_Shift)) == .pass)
    }

    @Test func aStrayReleaseSendsNoEscape() {
        var keyboard = Keyboard(tapsEscape: true)
        #expect(keyboard.send(.keyUp) == .pass)
    }

    @Test func eachTapStartsFresh() {
        var keyboard = Keyboard(tapsEscape: true)
        _ = keyboard.send(.keyDown)
        _ = keyboard.send(.keyDown, Self.letter)
        _ = keyboard.send(.keyUp)
        _ = keyboard.send(.keyDown)
        #expect(keyboard.send(.keyUp) == .escape)
    }
}
