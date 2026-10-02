import Carbon.HIToolbox
import CoreGraphics
import Testing

@testable import InputKit

@Suite struct SwitcherKeysTests {
    typealias Key = SwitcherKeys.Key

    final class Recorder {
        var keys = SwitcherKeys()
        var events: [SwitcherKeys.Event] = []
        var isOpen = true

        func send(_ type: CGEventType, _ flags: CGEventFlags) -> Bool {
            send(type, flags, keyCode: kVK_Option)
        }

        func send(_ type: CGEventType, _ flags: CGEventFlags, keyCode: Int) -> Bool {
            send(type, flags, Key(code: Int64(keyCode), isRepeat: false))
        }

        func holdTab(_ flags: CGEventFlags) -> Bool {
            send(.keyDown, flags, Key(code: Int64(kVK_Tab), isRepeat: true))
        }

        private func send(_ type: CGEventType, _ flags: CGEventFlags, _ key: Key) -> Bool {
            keys.handle(type, flags: flags, key: key, isOpen: isOpen) { event in
                events.append(event)
            }
        }
    }

    static let option: CGEventFlags = .maskAlternate

    @Test func nothingIsTouchedWhileClosed() {
        let recorder = Recorder()
        recorder.isOpen = false
        #expect(!recorder.send(.flagsChanged, Self.option))
        #expect(!recorder.send(.keyDown, Self.option, keyCode: kVK_ANSI_Q))
        #expect(!recorder.send(.keyUp, Self.option, keyCode: kVK_ANSI_Q))
        #expect(!recorder.send(.keyDown, Self.option, keyCode: kVK_Escape))
        #expect(!recorder.send(.flagsChanged, []))
        #expect(recorder.events.isEmpty)
    }

    @Test func releasingOptionChoosesAndPassesThrough() {
        let recorder = Recorder()
        #expect(!recorder.send(.flagsChanged, [.maskAlternate, .maskShift]))
        #expect(!recorder.send(.flagsChanged, Self.option))
        #expect(!recorder.send(.flagsChanged, []))
        #expect(recorder.events == [.chosen])
    }

    @Test func tabIsLeftToTheHotKeys() {
        let recorder = Recorder()
        #expect(!recorder.send(.keyDown, Self.option, keyCode: kVK_Tab))
        #expect(!recorder.send(.keyUp, Self.option, keyCode: kVK_Tab))
        #expect(recorder.events.isEmpty)
    }

    @Test func holdingTabStepsOnEachRepeatAndSwallowsIt() {
        let recorder = Recorder()
        #expect(!recorder.send(.keyDown, Self.option, keyCode: kVK_Tab))
        #expect(recorder.holdTab(Self.option))
        #expect(recorder.holdTab([.maskAlternate, .maskShift]))
        #expect(!recorder.send(.keyUp, Self.option, keyCode: kVK_Tab))
        #expect(recorder.events == [.stepped(backward: false), .stepped(backward: true)])
    }

    @Test func tabRepeatsPassThroughWhileClosed() {
        let recorder = Recorder()
        recorder.isOpen = false
        #expect(!recorder.holdTab(Self.option))
        #expect(recorder.events.isEmpty)
    }

    @Test func keysWhileOpenAreReportedAndSwallowedThroughTheirKeyUp() {
        let recorder = Recorder()
        #expect(recorder.send(.keyDown, Self.option, keyCode: kVK_ANSI_W))
        #expect(!recorder.send(.flagsChanged, []))
        recorder.isOpen = false
        #expect(recorder.send(.keyUp, [], keyCode: kVK_ANSI_W))
        #expect(!recorder.send(.keyUp, [], keyCode: kVK_ANSI_W))
        #expect(!recorder.send(.keyDown, [], keyCode: kVK_ANSI_W))
        #expect(recorder.events == [.pressed(keyCode: Int64(kVK_ANSI_W)), .chosen])
    }

    @Test func escapeCancelsAndIsSwallowedThroughItsKeyUp() {
        let recorder = Recorder()
        #expect(recorder.send(.keyDown, Self.option, keyCode: kVK_Escape))
        recorder.isOpen = false
        #expect(recorder.send(.keyUp, Self.option, keyCode: kVK_Escape))
        #expect(!recorder.send(.flagsChanged, []))
        #expect(recorder.events == [.cancelled])
    }

    @Test func aMissedReleaseIsCaughtFromTheNextKeysFlags() {
        let recorder = Recorder()
        #expect(!recorder.send(.keyDown, [], keyCode: kVK_ANSI_A))
        #expect(recorder.events == [.chosen])
    }
}
