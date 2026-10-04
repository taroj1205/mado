import AppCore
import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct TapKeyboardTests {
    func labels(in view: NSView) -> [String] {
        view.subviews.flatMap { child in
            [child.accessibilityLabel()].compactMap(\.self) + labels(in: child)
        }
    }

    @Test func namesWhatEachBoundModifierTapSelects() {
        let keyboard = TapKeyboard()
        keyboard.show([.leftCommand: "英数", .rightCommand: "かな", .rightShift: "Next"])

        #expect(labels(in: keyboard) == ["Left ⌘ tap: 英数", "Right ⌘ tap: かな"])
    }

    @Test func showsNoChipsWhenNothingIsBound() {
        let keyboard = TapKeyboard()
        keyboard.show([:])

        #expect(labels(in: keyboard).isEmpty)
    }
}
