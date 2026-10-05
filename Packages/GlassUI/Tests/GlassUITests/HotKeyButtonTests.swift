import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite struct HotKeyButtonTests {
    private let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 240, height: 80), styleMask: [.titled],
        backing: .buffered, defer: true)
    private let button = HotKeyButton()

    init() {
        window.contentView = button
    }

    private func key(_ keyCode: Int) throws -> NSEvent {
        try #require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: 0, context: nil, characters: " ", charactersIgnoringModifiers: " ",
                isARepeat: false, keyCode: UInt16(keyCode)))
    }

    @Test func aPressButtonTakesFocusOnlyForSearchAndSpacePressesIt() throws {
        var presses = 0
        button.onPress = { presses += 1 }
        #expect(!button.acceptsFirstResponder)

        button.takesSearchFocus = true
        #expect(button.acceptsFirstResponder)
        window.makeFirstResponder(button)
        #expect(window.firstResponder === button)
        #expect(!button.isRecording)
        #expect(button.focusRingMaskBounds == button.bounds)

        button.keyDown(with: try key(kVK_Space))
        #expect(presses == 1)

        window.makeFirstResponder(nil)
        #expect(!button.takesSearchFocus)
        #expect(button.focusRingMaskBounds == .zero)
    }

    @Test func aRecordingButtonStillRecordsWhenFocused() {
        window.makeFirstResponder(button)
        #expect(button.isRecording)

        window.makeFirstResponder(nil)
        #expect(!button.isRecording)
    }
}
