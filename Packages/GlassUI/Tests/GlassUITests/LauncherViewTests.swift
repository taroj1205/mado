import AppKit
import Carbon.HIToolbox
import QuickLookUI
import Testing

@testable import GlassUI

@MainActor
@Suite(.serialized) struct LauncherViewTests {
    private let panel = GlassPanel(
        kind: .panel, contentRect: NSRect(x: 0, y: 0, width: 760, height: 476),
        shape: .rounded(28))
    private let view = LauncherView()

    init() {
        panel.glass.contentView = view
        panel.onKeyDown = { [view] in view.handleKeyDown($0) }
        view.results.sections = [
            .init(
                title: "Applications",
                items: [item("Safari", action: "Open Application"), item("Notes")]),
            .init(title: "Commands", items: [item("Sleep")]),
        ]
        panel.makeFirstResponder(view.field)
    }

    @Test func arrowKeysMoveThroughRowsAndSkipHeaders() {
        press(kVK_DownArrow, "\u{F701}")
        press(kVK_DownArrow, "\u{F701}")
        #expect(view.results.selectedItem?.id == "Sleep")
        press(kVK_UpArrow, "\u{F700}")
        #expect(view.results.selectedItem?.id == "Notes")
        #expect(view.field.stringValue.isEmpty)
    }

    @Test func returnRunsThePrimaryActionAndCommandReturnTheSecondary() {
        var runs: [String] = []
        view.onRun = { runs.append("\($0.id) \($1)") }
        press(kVK_DownArrow, "\u{F701}")
        press(kVK_Return, "\r")
        press(kVK_ANSI_KeypadEnter, "\u{3}")
        press(kVK_Return, "\r", [.command])
        press(kVK_ANSI_KeypadEnter, "\u{3}", [.command])
        #expect(runs == ["Notes 0", "Notes 0", "Notes 1", "Notes 1"])
    }

    @Test func otherModifiedReturnsDoNotRunTheSecondaryAction() {
        var runs: [String] = []
        view.onRun = { runs.append("\($0.id) \($1)") }
        press(kVK_Return, "\r", [.command, .shift])
        press(kVK_Return, "\r", [.command, .option])
        #expect(runs.isEmpty)
    }

    @Test func commandReturnWaitsWhileTheInputMethodIsComposing() throws {
        var runs: [String] = []
        view.onRun = { runs.append("\($0.id) \($1)") }
        try compose("かいぎ")
        press(kVK_Return, "\r", [.command])
        #expect(runs.isEmpty)
    }

    @Test func returnCommitsTheInputMethodInsteadOfRunning() throws {
        var runs: [String] = []
        var queries: [String] = []
        view.onRun = { runs.append("\($0.id) \($1)") }
        view.onQuery = { queries.append($0) }
        try compose("かいぎ").doCommand(by: #selector(NSResponder.insertNewline))
        #expect(runs.isEmpty)
        #expect(queries == ["かいぎ"])
    }

    @Test func searchWaitsUntilTheInputMethodCommits() throws {
        var queries: [String] = []
        view.onQuery = { queries.append($0) }
        let editor = try compose("かいぎ")
        #expect(queries.isEmpty)
        editor.insertText("会議", replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(queries == ["会議"])
    }

    @Test func nothingRunsWithoutResults() {
        var runs: [String] = []
        view.onRun = { runs.append("\($0.id) \($1)") }
        view.results.sections = []
        press(kVK_Return, "\r")
        press(kVK_Return, "\r", [.command])
        #expect(runs.isEmpty)
    }

    @Test func typingAndEscapeReachTheirHandlers() {
        var queries: [String] = []
        var cancels = 0
        view.onQuery = { queries.append($0) }
        view.onCancel = { cancels += 1 }
        press(kVK_ANSI_A, "a")
        press(kVK_Escape, "\u{1B}")
        #expect(queries == ["a"])
        #expect(cancels == 1)
    }

    @Test func theCapsuleNamesTheSelectedRowsPrimaryAction() {
        let capsule = actionCapsule()
        #expect(!capsule.isHidden)
        #expect(view.actionLabel.stringValue == "Open Application")
        let width = capsule.frame.width
        press(kVK_DownArrow, "\u{F701}")
        #expect(view.actionLabel.stringValue == "Run Command")
        #expect(actionCapsule().frame.width < width)
        #expect(actionCapsule().frame.maxX == view.bounds.maxX - 10)
        #expect(actionCapsule().frame.minY == 10)
        let label = actionCapsule().convert(view.actionLabel.bounds, from: view.actionLabel)
        #expect(abs(label.midY - actionCapsule().bounds.midY) < 1)
        view.results.sections = []
        #expect(actionCapsule().isHidden)
    }

    @Test func theContextCapsuleShowsOnlyWhileThereIsContext() {
        #expect(view.contextCapsule.isHidden)
        view.context = "No results"
        view.layoutSubtreeIfNeeded()
        let capsule = view.contextCapsule
        #expect(!capsule.isHidden)
        #expect(view.contextLabel.stringValue == "No results")
        #expect(capsule.frame.minX == 10)
        #expect(capsule.frame.width >= view.contextLabel.fittingSize.width)
        view.context = nil
        #expect(capsule.isHidden)
    }

    @Test func rowsScrollUnderTheCapsuleButTheSelectionStopsAboveIt() {
        view.results.sections = [
            .init(title: "Commands", items: (0..<40).map { item("Command \($0)") })
        ]
        let capsule = actionCapsule()
        #expect(view.results.frame.minY == 0)
        for _ in 0..<39 {
            press(kVK_DownArrow, "\u{F701}")
        }
        let table = view.results.table
        #expect(view.results.selectedItem?.id == "Command 39")
        let row = view.convert(table.rect(ofRow: table.selectedRow), from: table)
        #expect(row.minY >= capsule.frame.maxY)
        #expect(view.results.contentView.bounds.maxY > table.frame.maxY)
    }

    private func actionCapsule() -> GlassView {
        view.layoutSubtreeIfNeeded()
        return view.actionCapsule
    }

    @Test func spaceTypesIntoTheQueryUntilTheSelectionMoves() {
        view.results.sections = [.init(title: "Files", items: [file("a.txt"), file("b.txt")])]
        #expect(view.contextCapsule.isHidden)
        press(kVK_Space, " ")
        #expect(view.field.stringValue == " ")
        #expect(!view.previewing)
    }

    @Test func spaceAfterMovingPreviewsTheFileAndEscapeClosesOnlyThePreview() {
        defer { view.closePreview() }
        var cancels = 0
        view.onCancel = { cancels += 1 }
        view.results.sections = [.init(title: "Files", items: [file("a.txt"), file("b.txt")])]
        press(kVK_DownArrow, "\u{F701}")
        #expect(view.contextLabel.stringValue == "Space to preview")
        #expect(!view.contextCapsule.isHidden)
        press(kVK_Space, " ")
        #expect(view.previewing)
        #expect(view.preview?.view?.previewItem?.previewItemURL?.lastPathComponent == "b.txt")
        #expect(view.preview?.title.stringValue == "b.txt")
        press(kVK_UpArrow, "\u{F700}")
        #expect(view.preview?.view?.previewItem?.previewItemURL?.lastPathComponent == "a.txt")
        press(kVK_Escape, "\u{1B}")
        #expect(!view.previewing)
        #expect(cancels == 0)
        #expect(view.field.stringValue.isEmpty)
    }

    @Test func typingClosesThePreviewAndSpaceTypesAgain() {
        defer { view.closePreview() }
        view.results.sections = [.init(title: "Files", items: [file("a.txt"), file("b.txt")])]
        press(kVK_DownArrow, "\u{F701}")
        press(kVK_Space, " ")
        press(kVK_ANSI_A, "a")
        #expect(!view.previewing)
        #expect(view.contextCapsule.isHidden)
        press(kVK_Space, " ")
        #expect(view.field.stringValue == "a ")
    }

    @Test func spaceTypesWhenTheSelectedRowIsNotAFile() {
        press(kVK_DownArrow, "\u{F701}")
        #expect(view.contextCapsule.isHidden)
        press(kVK_Space, " ")
        #expect(view.field.stringValue == " ")
        #expect(!view.previewing)
    }

    private func file(_ name: String) -> ResultList.Item {
        .init(
            id: name, title: name, subtitle: "", kind: "File", symbol: "", action: "Open",
            file: URL(filePath: "/tmp").appending(path: name))
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

    @discardableResult
    private func compose(_ text: String) throws -> NSTextView {
        let editor = try #require(view.field.currentEditor() as? NSTextView)
        editor.setMarkedText(
            text, selectedRange: NSRange(location: text.utf16.count, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: 0))
        return editor
    }

    private func item(_ title: String, action: String = "Run Command") -> ResultList.Item {
        .init(
            id: title, title: title, subtitle: "", kind: "Command", symbol: "star",
            action: action)
    }
}
