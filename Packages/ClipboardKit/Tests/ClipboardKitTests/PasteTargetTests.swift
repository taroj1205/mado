import AppKit
import Carbon.HIToolbox
import Testing

@testable import ClipboardKit

@MainActor
@Suite struct PasteTargetTests {
    @Test func neverTargetsMadoItselfOrNoApp() {
        #expect(PasteTarget(app: .current) == nil)
        #expect(PasteTarget(app: nil) == nil)
    }

    @Test func replacesWhatThePasteboardHeld() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("old", forType: .string)
        pasteboard.setString("<b>old</b>", forType: .html)

        let item = NSPasteboardItem()
        item.setString("new", forType: .string)
        try PasteTarget.write([item], to: pasteboard)

        #expect(pasteboard.string(forType: .string) == "new")
        #expect(pasteboard.string(forType: .html) == nil)
    }

    @Test func sendsCommandVDownThenUp() {
        let events = PasteTarget.commandV()

        #expect(events.count == 2)
        let keyV = Int64(kVK_ANSI_V)
        #expect(events.map { $0.getIntegerValueField(.keyboardEventKeycode) } == [keyV, keyV])
        #expect(events.map(\.type) == [.keyDown, .keyUp])
        #expect(events.allSatisfy { $0.flags == .maskCommand })
    }
}
