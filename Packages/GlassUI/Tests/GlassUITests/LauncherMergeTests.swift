import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite(.serialized) final class LauncherMergeTests {
    private let panel = GlassPanel(
        kind: .panel, contentRect: NSRect(x: 0, y: 0, width: 760, height: 476),
        shape: .rounded(28))
    private let view = LauncherView()
    private var runs: [(String, Int)] = []

    init() {
        panel.glass.contentView = view
        panel.onEvent = { [view] in view.handle($0) }
        view.results.reducesMotion = { true }
        view.onRun = { [weak self] item, action in self?.runs.append((item.id, action)) }
        view.actions = { _ in
            [
                .init("Paste", keys: LauncherView.Action.primaryKeys),
                .init("Copy", keys: LauncherView.Action.secondaryKeys),
            ]
        }
        view.enter(placeholder: "Filter", detail: .preview { _ in nil })
        view.show([.init(title: "Today", items: ["a", "b", "c"].map(item))])
        panel.makeFirstResponder(view.field)
    }

    private func item(_ id: String) -> ResultList.Item {
        .init(
            id: id, title: id, subtitle: "", kind: "Text", symbol: "text.alignleft",
            action: "Paste to Notes", isCheckable: true)
    }

    private func merge(
        action: String = "Paste Merged", item: String? = nil
    ) -> LauncherView.Merge {
        .init(
            title: "Merge 2 items", texts: ["a", "b"], joins: item == nil, note: "",
            action: action, item: item)
    }

    @Test func shiftDownChecksRowsAndCountsThemInTheContextPill() {
        press(kVK_DownArrow, "\u{F701}", [.shift])
        press(kVK_DownArrow, "\u{F701}", [.shift])
        #expect(view.results.checked == ["a", "b", "c"])
        #expect(view.contextPill.text == "3 selected")
        #expect(view.contextPill.symbol == "checkmark")
        view.results.clearChecks()
        #expect(view.contextPill.text != "3 selected")
    }

    @Test func aMergeReplacesThePreviewAndTheCapsuleLabel() {
        #expect(view.actionLabel.stringValue == "Paste to Notes")
        view.showMerge(merge())
        #expect(view.actionLabel.stringValue == "Paste Merged")
        #expect(view.detail.isHidden)
        #expect(!view.mergePane.isHidden)
        #expect(view.mergeDraft?.text == "a\nb")
        view.showMerge(nil)
        #expect(view.actionLabel.stringValue == "Paste to Notes")
        #expect(view.mergePane.isHidden)
        #expect(!view.detail.isHidden)
        #expect(view.mergeDraft == nil)
    }

    @Test func commandEAsksToEditTheSelectedItem() {
        var edited: [String] = []
        view.onEdit = { edited.append($0.id) }
        press(kVK_ANSI_E, "e", [.command])
        #expect(edited == ["a"])
    }

    @Test func commandEFocusesAnOpenMergeAndSwapsTheKeycap() {
        view.showMerge(merge())
        press(kVK_ANSI_E, "e", [.command])
        #expect(view.mergePane.isEditing)
        #expect((view.actionKeycap as? Keycap)?.name.stringValue == "⌘↵")
    }

    @Test func commandEDoesNothingWithoutAnEditHandlerOrAMerge() {
        press(kVK_ANSI_E, "e", [.command])
        #expect(!view.mergePane.isEditing)
    }

    @Test func commandReturnInTheEditorRunsThePrimaryAction() {
        view.showMerge(merge())
        view.mergePane.focus()
        press(kVK_Return, "\r", [.command])
        #expect(runs.map(\.1) == [0])
    }

    @Test func commandReturnInTheEditorCopiesWhenThereIsNothingToPasteInto() {
        view.showMerge(merge(action: ""))
        view.mergePane.focus()
        press(kVK_Return, "\r", [.command])
        #expect(runs.map(\.1) == [1])
    }

    @Test func escapeInTheEditorResetsAMergeAndKeepsItsSelection() {
        view.showMerge(merge())
        view.mergePane.focus()
        view.mergePane.editor.string = "changed"
        press(kVK_Escape, "\u{1B}")
        #expect(!view.mergePane.isEditing)
        #expect(view.mergeDraft?.text == "a\nb")
    }

    @Test func escapeInTheEditorClosesASingleItemEdit() {
        view.showMerge(merge(item: "a"))
        view.mergePane.focus()
        press(kVK_Escape, "\u{1B}")
        #expect(view.mergeDraft == nil)
        #expect(view.mergePane.isHidden)
        #expect(runs.isEmpty)
    }

    @Test func escapeInTheFieldClearsChecksBeforeLeavingTheScope() {
        press(kVK_DownArrow, "\u{F701}", [.shift])
        press(kVK_Escape, "\u{1B}")
        #expect(view.results.checked.isEmpty)
        #expect(view.scoped)
        press(kVK_Escape, "\u{1B}")
        #expect(!view.scoped)
    }

    @Test func movingOffTheEditedItemEndsTheEditButAMergeSurvives() {
        view.showMerge(merge(item: "a"))
        view.results.selectNext()
        #expect(view.mergeDraft == nil)
        view.showMerge(merge())
        view.results.selectNext()
        #expect(view.mergeDraft != nil)
    }

    @Test func clickingARowTakesFocusBackFromTheEditor() {
        view.showMerge(merge())
        view.mergePane.focus()
        view.selectionMoved()
        #expect(!view.mergePane.isEditing)
    }

    @Test func leavingTheScopeDropsTheChecksAndTheMerge() {
        press(kVK_DownArrow, "\u{F701}", [.shift])
        view.showMerge(merge())
        view.leave()
        #expect(view.results.checked.isEmpty)
        #expect(view.mergeDraft == nil)
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
