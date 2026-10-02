import AppCore
import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite(.serialized) final class QuicklinkSheetTests {
    private let panel = GlassPanel(
        kind: .panel, contentRect: NSRect(x: 100, y: 100, width: 760, height: 476),
        shape: .rounded(28))
    private let sheet = QuicklinkSheet()
    private let safari = URL(filePath: "/Applications/Safari.app")
    private let chrome = URL(filePath: "/Applications/Google Chrome.app")
    private let finder = URL(filePath: "/System/Library/CoreServices/Finder.app")
    private let controlOptionY = Shortcut(
        keyCode: UInt32(kVK_ANSI_Y), modifiers: [.control, .option])
    private lazy var youtube = QuicklinkSheet.Values(
        name: "YouTube", link: "https://youtube.com/results?search_query={query}", app: safari,
        alias: "yt", hotkey: controlOptionY)

    init() {
        panel.glass.contentView = sheet
        sheet.applications = { [safari, chrome, finder] link in
            link.hasPrefix("~") ? [finder] : link.isEmpty ? [] : [safari, chrome]
        }
    }

    @Test func showsTheQuicklinkLikeTheCanvas() {
        sheet.show(youtube, editing: false)

        #expect(sheet.heading.stringValue == "New Quicklink")
        #expect(sheet.nameField.stringValue == "YouTube")
        #expect(sheet.linkField.font?.isFixedPitch == true)
        #expect(
            sheet.linkHint.stringValue
                == "Put {query} where the search text should go. "
                + "Also works with folders and app deep links.")
        #expect(sheet.openWith.itemTitles == ["Safari", "Google Chrome"])
        #expect(sheet.openWith.selectedItem?.representedObject as? URL == safari)
        #expect(sheet.aliasHint.stringValue == "Type “yt cats” in root search to jump straight in.")
        #expect(sheet.hotkey.accessibilityValue() as? String == "⌃ ⌥ Y")
        #expect(sheet.problemLabel.isHidden)
        #expect(sheet.contextLabel.stringValue == "Quicklinks")
        #expect(sheet.save.accessibilityLabel() == "Save Quicklink")
        #expect(panel.firstResponder === sheet.nameField.currentEditor())

        sheet.show(.init(), editing: true)
        #expect(sheet.heading.stringValue == "Edit Quicklink")
        #expect(!sheet.openWith.isEnabled)
        #expect(sheet.aliasHint.stringValue == "Type the alias in root search to jump straight in.")
    }

    @Test func editingTheLinkListsItsAppsAndKeepsTheChoiceWhileItStillFits() {
        sheet.show(youtube, editing: true)
        sheet.openWith.selectItem(at: 1)

        type("https://www.google.com/search?q={query}", in: sheet.linkField)
        #expect(sheet.openWith.selectedItem?.representedObject as? URL == chrome)

        type("~/Projects", in: sheet.linkField)
        #expect(sheet.openWith.itemArray.compactMap { $0.representedObject as? URL } == [finder])
        #expect(sheet.aliasHint.stringValue == "Type “yt” in root search to jump straight in.")
    }

    @Test func aSavedAppThatNoLongerOpensTheLinkStaysListed() {
        sheet.show(.init(name: "Projects", link: "~/Projects", app: chrome), editing: true)
        #expect(
            sheet.openWith.itemArray.compactMap { $0.representedObject as? URL }
                == [finder, chrome])
        #expect(sheet.openWith.selectedItem?.representedObject as? URL == chrome)
    }

    @Test func returnSavesTrimmedValuesAndEscapeCancels() {
        var saved: [QuicklinkSheet.Values] = []
        var cancels = 0
        sheet.onSave = { values in
            saved.append(values)
            return nil
        }
        sheet.onCancel = { cancels += 1 }
        sheet.show(youtube, editing: false)
        sheet.nameField.stringValue = "  YouTube "
        sheet.aliasField.stringValue = " yt "

        press(kVK_Return, "\r")
        press(kVK_Escape, "\u{1B}")

        #expect(saved == [youtube])
        #expect(cancels == 1)
        #expect(sheet.cancel.accessibilityPerformPress())
        #expect(cancels == 2)
    }

    @Test func aMissingNameOrLinkBlocksSavingAndFocusesTheField() {
        var saved: [QuicklinkSheet.Values] = []
        sheet.onSave = { values in
            saved.append(values)
            return nil
        }
        sheet.show(.init(link: "https://example.com"), editing: false)
        #expect(sheet.save.accessibilityPerformPress())
        #expect(panel.firstResponder === sheet.nameField.currentEditor())

        sheet.show(.init(name: "Example"), editing: false)
        #expect(sheet.save.accessibilityPerformPress())
        #expect(panel.firstResponder === sheet.linkField.currentEditor())
        #expect(saved.isEmpty)
    }

    @Test func aHotkeyConflictOrSaveProblemShowsUnderTheHotkey() {
        sheet.conflict = { [controlOptionY] in $0 == controlOptionY ? "Terminal" : nil }
        var saved = 0
        sheet.onSave = { _ in
            saved += 1
            return "macOS wouldn’t register this hotkey. Try another."
        }
        sheet.show(.init(name: "YouTube", link: "https://youtube.com"), editing: false)
        panel.makeFirstResponder(sheet.hotkey)

        press(kVK_ANSI_Y, "y", [.control, .option])
        #expect(sheet.problemLabel.stringValue == "Terminal already uses ⌃⌥Y.")
        #expect(!sheet.problemLabel.isHidden)
        #expect(sheet.hotkey.conflict)
        press(kVK_Return, "\r")
        #expect(saved == 0)

        press(kVK_Delete, "\u{7F}")
        #expect(sheet.problemLabel.isHidden)
        press(kVK_Return, "\r")
        #expect(saved == 1)
        #expect(
            sheet.problemLabel.stringValue == "macOS wouldn’t register this hotkey. Try another.")
    }

    @Test func useWebsiteIconFetchesForTheTypedLink() async throws {
        let image = NSImage(size: NSSize(width: 4, height: 4), flipped: false) { rect in
            NSColor.systemRed.setFill()
            rect.fill()
            return true
        }
        let png = try #require(
            image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:))?
                .representation(using: .png, properties: [:]))
        var asked: [String] = []
        sheet.websiteIcon = { link in
            asked.append(link)
            return png
        }
        sheet.show(.init(name: "YouTube", link: " https://youtube.com "), editing: false)
        #expect(sheet.tile.borderWidth > 0)

        sheet.useWebsiteIcon.performClick(nil)
        while !sheet.useWebsiteIcon.isEnabled {
            await Task.yield()
        }

        #expect(asked == ["https://youtube.com"])
        #expect(sheet.icon == png)
        #expect(sheet.tile.borderWidth == 0)
    }

    @Test func layoutFollowsTheCanvas() {
        sheet.show(youtube, editing: false)
        sheet.layoutSubtreeIfNeeded()
        let capsules = sheet.subviews.compactMap { $0 as? GlassView }.map(\.frame)
        let box = { (field: NSTextField) in
            sequence(first: field as NSView) { unsafe $0.superview }.first { $0 is NSBox }?.frame
        }

        #expect(capsules.map(\.minY) == [10, 10])
        #expect(box(sheet.aliasField)?.size == NSSize(width: 120, height: 28))
        #expect(box(sheet.nameField)?.width == 566)
        #expect(box(sheet.linkField)?.width == box(sheet.nameField)?.width)
        #expect(sheet.openWith.frame.width == 220)
        #expect(sheet.tile.frame.size == NSSize(width: 28, height: 28))
        #expect(sheet.convert(sheet.hotkey.bounds, from: sheet.hotkey).minY > 60)
        let ambiguous = sheet.subviews.contains(where: \.hasAmbiguousLayout)
        #expect(!ambiguous)
    }

    private func type(_ text: String, in field: NSTextField) {
        panel.makeFirstResponder(field)
        field.stringValue = text
        NotificationCenter.default.post(
            name: NSControl.textDidChangeNotification, object: field)
    }

    private func press(
        _ keyCode: Int, _ characters: String, _ modifiers: NSEvent.ModifierFlags = []
    ) {
        guard
            let event = NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
                windowNumber: panel.windowNumber, context: nil, characters: characters,
                charactersIgnoringModifiers: characters, isARepeat: false,
                keyCode: UInt16(keyCode))
        else {
            Issue.record("Could not make a key event for \(keyCode)")
            return
        }
        if modifiers.contains(.command), panel.performKeyEquivalent(with: event) { return }
        panel.sendEvent(event)
    }

    isolated deinit {
        panel.makeFirstResponder(nil)
    }
}
