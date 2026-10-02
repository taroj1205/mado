import AppCore
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

    @Test func namesTheAppItPastesInto() throws {
        let app = try #require(
            NSWorkspace.shared.runningApplications.first { app in
                app != .current && app.localizedName != nil
            })
        let action = try #require(PasteTarget(app: app)).action(pasting: "42")

        #expect(action.id == "paste")
        #expect(action.title == "Paste to \(app.localizedName ?? "")")
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
