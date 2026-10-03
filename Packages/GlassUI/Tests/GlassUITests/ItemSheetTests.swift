import AppCore
import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite(.serialized) final class ItemSheetTests {
    private let panel = GlassPanel(
        kind: .panel, contentRect: NSRect(x: 100, y: 100, width: 760, height: 476),
        shape: .rounded(28))
    private let sheet = ItemSheet()
    private let terminal = ResultList.Item(
        id: "/System/Applications/Utilities/Terminal.app", title: "Terminal",
        subtitle: "/System/Applications/Utilities", kind: "Application", symbol: "terminal",
        action: "Open Application")
    private let controlOptionT = Shortcut(
        keyCode: UInt32(kVK_ANSI_T), modifiers: [.control, .option])

    init() {
        panel.glass.contentView = sheet
    }

    @Test func showsTheResultsAliasesHotkeyFavouriteAndRanking() {
        sheet.show(
            terminal,
            values: .init(aliases: ["t", "term"], hotkey: controlOptionT, favourite: true),
            ranking: "Opened 214 times · last today, 9:12", opening: .hotkey)

        #expect(sheet.title.stringValue == "Terminal")
        #expect(sheet.subtitle.stringValue == "Application · /System/Applications/Utilities")
        #expect(sheet.chips.views.count == 2)
        #expect(
            sheet.aliasHintLabel.stringValue
                == "An exact alias match always ranks first — “t” opens Terminal before "
                + "anything else starting with t.")
        #expect(sheet.hotkey.shortcut == controlOptionT)
        #expect(sheet.hotkey.accessibilityValue() as? String == "⌃ ⌥ T")
        #expect(!sheet.clear.isHidden)
        #expect(sheet.hotkeyHintLabel.stringValue == ItemSheet.hotkeyHint)
        #expect(sheet.favourite.state == .on)
        #expect(sheet.favourite.accessibilityLabel() == "Pin Terminal to Favourites")
        #expect(sheet.ranking.stringValue == "Opened 214 times · last today, 9:12")
        #expect(sheet.resetRanking.isEnabled)
        #expect(sheet.contextPill.text == "⌘K › Assign Hotkey")
        #expect(panel.firstResponder === sheet.hotkey)
        #expect(sheet.hotkey.isRecording)
    }

    @Test func eachActionFocusesItsOwnField() {
        sheet.show(terminal, values: .init(), ranking: nil, opening: .aliases)
        #expect(panel.firstResponder === sheet.aliasField.currentEditor())
        #expect(sheet.contextPill.text == "⌘K › Add Alias")
        #expect(sheet.aliasHintLabel.stringValue == "An exact alias match always ranks first.")
        #expect(sheet.ranking.stringValue == "Not opened yet")
        #expect(!sheet.resetRanking.isEnabled)
        #expect(sheet.clear.isHidden)

        sheet.show(terminal, values: .init(), ranking: nil, opening: .favourite)
        #expect(sheet.favourite.state == .on)
        #expect(sheet.contextPill.text == "⌘K › Add to Favourites")

        sheet.show(terminal, values: .init(favourite: true), ranking: nil, opening: .favourite)
        #expect(sheet.favourite.state == .off)
        #expect(sheet.contextPill.text == "⌘K › Remove from Favourites")
    }

    @Test func returnAddsTheTypedAliasAndSavesOnceTheFieldIsEmpty() {
        var saved: [ItemSheet.Values] = []
        sheet.onSave = { values in
            saved.append(values)
            return nil
        }
        sheet.show(terminal, values: .init(aliases: ["t"]), ranking: nil, opening: .aliases)

        sheet.aliasField.stringValue = "term"
        press(kVK_Return, "\r")
        sheet.aliasField.stringValue = " T "
        press(kVK_Return, "\r")
        #expect(sheet.aliases == ["t", "term"])
        #expect(saved.isEmpty)

        press(kVK_Return, "\r")
        #expect(saved == [.init(aliases: ["t", "term"])])
    }

    @Test func saveKeepsTextStillInTheFieldAndCancelDropsEverything() {
        var saved: [ItemSheet.Values] = []
        var cancels = 0
        sheet.onSave = { values in
            saved.append(values)
            return nil
        }
        sheet.onCancel = { cancels += 1 }
        sheet.show(terminal, values: .init(), ranking: nil, opening: .aliases)

        sheet.aliasField.stringValue = "tm"
        #expect(sheet.save.accessibilityPerformPress())
        #expect(saved == [.init(aliases: ["tm"])])

        press(kVK_Escape, "\u{1B}")
        #expect(sheet.cancel.accessibilityPerformPress())
        #expect(cancels == 2)
        #expect(saved.count == 1)
    }

    @Test func removingAChipDropsThatAlias() throws {
        sheet.show(
            terminal, values: .init(aliases: ["t", "term"]), ranking: nil, opening: .aliases)
        let remove = try #require(
            sheet.chips.views.first.flatMap { button(labelled: "Remove alias t", in: $0) })

        remove.performClick(nil)

        #expect(sheet.aliases == ["term"])
        #expect(sheet.chips.views.count == 1)
    }

    @Test func aConflictIsFlaggedAndBlocksSavingUntilCleared() {
        var saved: [ItemSheet.Values] = []
        sheet.conflict = { [controlOptionT] in $0 == controlOptionT ? "Safari" : nil }
        sheet.onSave = { values in
            saved.append(values)
            return nil
        }
        sheet.show(terminal, values: .init(), ranking: nil, opening: .hotkey)
        #expect(sheet.hotkey.accessibilityValue() as? String == "Press keys…")

        press(kVK_ANSI_T, "t", [.control, .option])
        #expect(sheet.hotkey.shortcut == controlOptionT)
        #expect(sheet.hotkey.conflict)
        #expect(sheet.hotkeyHintLabel.stringValue == "Safari already uses ⌃⌥T.")
        press(kVK_Return, "\r")
        #expect(saved.isEmpty)

        press(kVK_Delete, "\u{7F}")
        #expect(sheet.hotkey.shortcut == nil)
        #expect(!sheet.hotkey.conflict)
        #expect(sheet.clear.isHidden)
        press(kVK_Return, "\r")
        #expect(saved == [.init()])
    }

    @Test func theItemsOwnHotkeyIsNotAConflictAndShiftAloneIsNotAChord() {
        sheet.conflict = { _ in "Terminal" }
        sheet.show(terminal, values: .init(hotkey: controlOptionT), ranking: nil, opening: .hotkey)

        press(kVK_ANSI_X, "X", [.shift])
        press(kVK_ANSI_T, "t", [.control, .option])

        #expect(sheet.hotkey.shortcut == controlOptionT)
        #expect(!sheet.hotkey.conflict)
    }

    @Test func aProblemFromSavingStaysOnScreen() {
        let problem = "macOS wouldn’t register this hotkey. Try another."
        sheet.onSave = { _ in problem }
        sheet.show(terminal, values: .init(), ranking: nil, opening: .hotkey)

        press(kVK_ANSI_T, "t", [.control, .option])
        press(kVK_Return, "\r")

        #expect(sheet.hotkeyHintLabel.stringValue == problem)
        #expect(sheet.hotkey.conflict)
        #expect(!sheet.hotkey.isRecording)
    }

    @Test func recordingLastsWhileTheHotkeyHasFocus() {
        var recording: [Bool] = []
        sheet.onRecording = { recording.append($0) }
        sheet.show(terminal, values: .init(), ranking: nil, opening: .hotkey)
        press(kVK_Tab, "\t")
        #expect(recording == [true, false])

        panel.makeFirstResponder(sheet.hotkey)
        panel.glass.contentView = nil
        #expect(recording == [true, false, true, false])
    }

    @Test func tabGoesFromTheSheetToTheAliasFieldAndThenTheHotkey() {
        sheet.show(terminal, values: .init(), ranking: nil, opening: .aliases)
        panel.makeFirstResponder(sheet)
        press(kVK_Tab, "\t")
        #expect(panel.firstResponder === sheet.aliasField.currentEditor())
        press(kVK_Tab, "\t")
        #expect(panel.firstResponder === sheet.hotkey)
    }

    @Test func resetRankingWaitsForSave() {
        var saved: [ItemSheet.Values] = []
        sheet.onSave = { values in
            saved.append(values)
            return nil
        }
        sheet.show(terminal, values: .init(), ranking: "Opened 3 times", opening: .aliases)

        sheet.resetRanking.performClick(nil)
        #expect(sheet.ranking.stringValue == "Not opened yet")
        #expect(!sheet.resetRanking.isEnabled)
        #expect(saved.isEmpty)

        press(kVK_Return, "\r")
        #expect(saved == [.init(resetsRanking: true)])
    }

    @Test func theModeRowStillFitsAboveTheCapsules() throws {
        sheet.show(terminal, values: .init(), ranking: nil, opening: .hotkey, isApp: true)
        sheet.layoutSubtreeIfNeeded()
        let capsuleTop = try #require(
            sheet.subviews.compactMap { $0 as? GlassView }.map(\.frame.maxY).max())
        let ranking = sheet.convert(sheet.resetRanking.bounds, from: sheet.resetRanking)
        let mode = sheet.convert(sheet.mode.bounds, from: sheet.mode)
        let hotkey = sheet.convert(sheet.hotkey.bounds, from: sheet.hotkey)

        #expect(mode.maxY < hotkey.minY)
        #expect(ranking.minY > capsuleTop)
        let ambiguous = sheet.subviews.contains(where: \.hasAmbiguousLayout)
        #expect(!ambiguous)
    }

    @Test func layoutFollowsTheCanvas() {
        sheet.show(terminal, values: .init(aliases: ["t"]), ranking: nil, opening: .aliases)
        sheet.layoutSubtreeIfNeeded()
        let buttons = sheet.subviews.compactMap { $0 as? GlassView }.map(\.frame)
        let pill = sheet.contextPill.frame
        let hotkey = sheet.convert(sheet.hotkey.bounds, from: sheet.hotkey)
        let aliasBox = sequence(first: sheet.aliasField as NSView) { unsafe $0.superview }
            .first { $0 is NSBox }

        #expect(buttons.map(\.minY) == [10])
        #expect(buttons.map(\.maxX) == [sheet.bounds.maxX - 10])
        #expect(pill.minX == 10)
        #expect(pill.height == 36)
        #expect(abs(pill.midY - (buttons.first?.midY ?? 0)) < 1)
        #expect(sheet.hotkey.frame.height == 26)
        #expect(hotkey.maxY < sheet.bounds.height - 64)
        #expect(aliasBox?.frame.size == NSSize(width: 120, height: 28))
        let ambiguous = sheet.subviews.contains(where: \.hasAmbiguousLayout)
        #expect(!ambiguous)
    }

    private func button(labelled label: String, in view: NSView) -> NSButton? {
        for child in view.subviews {
            if let button = child as? NSButton, button.accessibilityLabel() == label {
                return button
            }
            if let match = button(labelled: label, in: child) {
                return match
            }
        }
        return nil
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
