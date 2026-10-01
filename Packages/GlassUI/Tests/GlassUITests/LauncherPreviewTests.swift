import AppKit
import Carbon.HIToolbox
import QuickLookUI
import Testing

@testable import GlassUI

@MainActor
@Suite(.serialized) struct LauncherPreviewTests {
    private let panel = GlassPanel(
        kind: .panel, contentRect: NSRect(x: 0, y: 0, width: 760, height: 476),
        shape: .rounded(28))
    private let view = LauncherView()

    init() {
        panel.glass.contentView = view
        panel.onEvent = { [view] in view.handle($0) }
        view.results.sections = [
            .init(title: "Applications", items: [item("Safari"), item("Notes")]),
            .init(title: "Commands", items: [item("Sleep")]),
        ]
        panel.makeFirstResponder(view.field)
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

    @Test func refreshedResultsKeepTheRowThePreviewIsOn() {
        defer { view.closePreview() }
        let files = [file("a.txt"), file("b.txt")]
        view.show([.init(title: "Files", items: files)])
        press(kVK_DownArrow, "\u{F701}")
        press(kVK_Space, " ")
        view.show([.init(title: "Files", items: [file("new.txt")] + files)])
        #expect(view.results.selectedItem?.id == "b.txt")
        #expect(view.previewing)
        view.show([.init(title: "Files", items: [file("new.txt"), file("a.txt")])])
        #expect(view.results.selectedItem?.id == "new.txt")
        #expect(!view.previewing)
    }

    @Test func clickingAnotherRowMovesThePreviewOrClosesIt() {
        defer { view.closePreview() }
        view.show([
            .init(title: "Files", items: [file("a.txt"), file("b.txt")]),
            .init(title: "Commands", items: [item("Sleep")]),
        ])
        press(kVK_DownArrow, "\u{F701}")
        press(kVK_Space, " ")
        view.results.table.selectRowIndexes([1], byExtendingSelection: false)
        #expect(view.preview?.title.stringValue == "a.txt")
        view.results.table.selectRowIndexes([4], byExtendingSelection: false)
        #expect(view.results.selectedItem?.id == "Sleep")
        #expect(!view.previewing)
    }

    @Test func aRowPickedWithTheMouseSurvivesARefresh() {
        let files = [file("a.txt"), file("b.txt")]
        view.show([.init(title: "Files", items: files)])
        view.results.table.selectRowIndexes([2], byExtendingSelection: false)
        click()
        view.show([.init(title: "Files", items: [file("new.txt")] + files)])
        #expect(view.results.selectedItem?.id == "b.txt")
        #expect(view.contextLabel.stringValue == "Space to preview")
    }

    @Test func movingTheCaretOrClickingTheFieldEndsBrowsing() throws {
        view.show([.init(title: "Files", items: [file("a.txt"), file("b.txt")])])
        press(kVK_DownArrow, "\u{F701}")
        press(kVK_LeftArrow, "\u{F702}")
        press(kVK_Space, " ")
        #expect(view.field.stringValue == " ")
        #expect(!view.previewing)

        press(kVK_DownArrow, "\u{F701}")
        let field = view.field.convert(view.field.bounds, to: nil)
        let click = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown, location: CGPoint(x: field.midX, y: field.midY),
                modifierFlags: [], timestamp: 0, windowNumber: panel.windowNumber, context: nil,
                eventNumber: 0, clickCount: 1, pressure: 1))
        #expect(!view.handle(click))
        #expect(view.contextCapsule.isHidden)
        press(kVK_Space, " ")
        #expect(view.field.stringValue == "  ")
    }

    @Test func clickingTheAlreadySelectedFileLetsSpacePreviewIt() {
        defer { view.closePreview() }
        view.show([.init(title: "Files", items: [file("a.txt"), file("b.txt")])])
        click()
        press(kVK_Space, " ")
        #expect(view.previewing)
        #expect(view.field.stringValue.isEmpty)
    }

    @Test func aRefreshRedrawsTheCardForAFileEditedInPlace() throws {
        defer { view.closePreview() }
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).txt")
        try Data().write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let old = Date(timeIntervalSinceNow: -86_400 * 3)
        try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: url.path)
        let row = ResultList.Item(
            id: url.path, title: "x", subtitle: "", kind: "File", symbol: "", action: "Open",
            file: url)
        let sections = [ResultList.Section(title: "Files", items: [file("a.txt"), row])]
        view.show(sections)
        press(kVK_DownArrow, "\u{F701}")
        press(kVK_Space, " ")
        #expect(view.preview?.modified.stringValue == FilePreview.modifiedText(old))
        try FileManager.default.setAttributes([.modificationDate: Date.now], ofItemAtPath: url.path)
        view.show(sections)
        #expect(view.previewing)
        #expect(view.preview?.modified.stringValue != FilePreview.modifiedText(old))
    }

    @Test func closingTheLauncherEndsBrowsingSoSpaceTypesAgain() {
        view.show([.init(title: "Files", items: [file("a.txt"), file("b.txt")])])
        press(kVK_DownArrow, "\u{F701}")
        press(kVK_Space, " ")
        view.endBrowsing()
        #expect(!view.previewing)
        #expect(view.contextCapsule.isHidden)
        press(kVK_Space, " ")
        #expect(view.field.stringValue == " ")
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

    private func item(_ title: String) -> ResultList.Item {
        .init(id: title, title: title, subtitle: "", kind: "Command", symbol: "star", action: "Run")
    }

    private func click() {
        view.results.table.sendAction(view.results.table.action, to: view.results.table.target)
    }

    private func press(_ keyCode: Int, _ characters: String) {
        guard
            let event = NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: panel.windowNumber, context: nil, characters: characters,
                charactersIgnoringModifiers: characters, isARepeat: false,
                keyCode: UInt16(keyCode))
        else {
            Issue.record("Could not make a key event for \(keyCode)")
            return
        }
        panel.sendEvent(event)
    }
}
