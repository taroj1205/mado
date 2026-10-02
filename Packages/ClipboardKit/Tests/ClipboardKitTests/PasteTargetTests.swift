import AppKit
import Carbon.HIToolbox
import InputKit
import IOKit.hidsystem
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

    @Test func sendsCommandVDownThenUp() throws {
        let events = try PasteTarget.commandV()

        let keyV = Int64(KeyboardLayout.commandKeyCode(typing: "v") ?? CGKeyCode(kVK_ANSI_V))
        let leftCommand = CGEventFlags.maskCommand.rawValue | UInt64(NX_DEVICELCMDKEYMASK)
        #expect(events.map { $0.getIntegerValueField(.keyboardEventKeycode) } == [keyV, keyV])
        #expect(events.map(\.type) == [.keyDown, .keyUp])
        #expect(events.allSatisfy { $0.flags.rawValue == leftCommand })
    }
}
