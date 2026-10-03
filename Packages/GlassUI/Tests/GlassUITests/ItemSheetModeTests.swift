import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite(.serialized) final class ItemSheetModeTests {
    private static let toggleHint =
        "Toggle: launch if closed → bring to front → hide if already in front."
    private static let quickPeekHint =
        "Quick Peek: the app hides itself again when you switch away."

    private let panel = GlassPanel(
        kind: .panel, contentRect: NSRect(x: 100, y: 100, width: 760, height: 476),
        shape: .rounded(28))
    private let sheet = ItemSheet()
    private let dictionary = ResultList.Item(
        id: "/System/Applications/Dictionary.app", title: "Dictionary",
        subtitle: "/System/Applications", kind: "Application", symbol: "book",
        action: "Open Application")

    init() {
        panel.glass.contentView = sheet
    }

    @Test func appsShowBothModesAndOtherItemsDoNot() {
        sheet.show(dictionary, values: .init(), ranking: nil, opening: .hotkey, isApp: true)
        #expect(!sheet.modeRow.isHidden)
        #expect(sheet.mode.itemTitles == ["Toggle", "Quick Peek"])
        #expect(sheet.mode.itemArray.map(\.isEnabled) == [true, true])
        #expect(sheet.mode.titleOfSelectedItem == "Toggle")
        #expect(sheet.mode.accessibilityLabel() == "Dictionary mode")
        #expect(sheet.modeHint.stringValue == Self.toggleHint)
        #expect(sheet.hotkeyHintLabel.stringValue == ItemSheet.hotkeyHint)

        sheet.show(dictionary, values: .init(), ranking: nil, opening: .hotkey)
        #expect(sheet.modeRow.isHidden)
    }

    @Test func showsTheSavedModeAndSavesTheChosenOne() {
        var saved: [ItemSheet.Values] = []
        sheet.onSave = { values in
            saved.append(values)
            return nil
        }
        sheet.show(
            dictionary, values: .init(quickPeek: true), ranking: nil, opening: .hotkey,
            isApp: true)
        #expect(sheet.mode.titleOfSelectedItem == "Quick Peek")
        #expect(sheet.modeHint.stringValue == Self.quickPeekHint)

        choose("Toggle")
        #expect(sheet.modeHint.stringValue == Self.toggleHint)
        choose("Quick Peek")
        #expect(sheet.modeHint.stringValue == Self.quickPeekHint)
        #expect(sheet.save.accessibilityPerformPress())
        #expect(saved == [.init(quickPeek: true)])

        sheet.show(dictionary, values: .init(), ranking: nil, opening: .hotkey, isApp: true)
        #expect(sheet.mode.titleOfSelectedItem == "Toggle")
        #expect(sheet.modeHint.stringValue == Self.toggleHint)
    }

    private func choose(_ title: String) {
        let index = sheet.mode.indexOfItem(withTitle: title)
        sheet.mode.menu?.performActionForItem(at: index)
    }

    isolated deinit {
        panel.makeFirstResponder(nil)
    }
}
