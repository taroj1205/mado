import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite(.serialized) final class ActionChoicesTests {
    private let panel = GlassPanel(
        kind: .panel, contentRect: NSRect(x: 100, y: 100, width: 760, height: 476),
        shape: .rounded(28))
    private let view = LauncherView()
    private var runs: [String] = []
    private var opened: [String] = []

    init() {
        panel.glass.contentView = view
        view.results.sections = [
            .init(
                title: "Results",
                items: [
                    .init(
                        id: "report.pdf", title: "report.pdf", subtitle: "", kind: "PDF",
                        symbol: "doc", action: "Open")
                ])
        ]
        view.onRun = { [weak self] in self?.runs.append("\($0.id) \($1)") }
        panel.makeFirstResponder(view.field)
    }

    @Test func choicesShowInThePanelAndEscapeGoesBackToTheActions() throws {
        offer(["Preview", "Safari"])
        press(kVK_ANSI_K, "k", [.command])
        let menu = try #require(view.actionPanel)
        press(kVK_DownArrow, "\u{F701}")
        press(kVK_Return, "\r")
        #expect(runs.isEmpty)
        #expect(view.choosingAction)
        #expect(menu.header.stringValue == "Open With")
        #expect(menu.rows.map(\.label.stringValue) == ["Preview", "Safari"])
        #expect(menu.rows.map(\.isSelected) == [true, false])
        #expect(
            menu.rows.allSatisfy { $0.contentView?.subviews.contains { $0 is NSImageView } == true }
        )
        type("saf", in: menu)
        #expect(menu.rows.map(\.label.stringValue) == ["Safari"])

        press(kVK_Escape, "\u{1B}")
        #expect(view.choosingAction)
        #expect(menu.header.stringValue == "report.pdf")
        #expect(menu.field.stringValue.isEmpty)
        #expect(menu.rows.map(\.label.stringValue) == ["Open", "Open With…"])
        press(kVK_Escape, "\u{1B}")
        #expect(!view.choosingAction)
    }

    @Test func pickingAChoiceRunsItAndClosesThePanel() throws {
        offer(["Preview", "Safari"])
        press(kVK_ANSI_K, "k", [.command])
        let menu = try #require(view.actionPanel)
        #expect(menu.rows[1].accessibilityPerformPress())
        press(kVK_DownArrow, "\u{F701}")
        press(kVK_Return, "\r")
        #expect(opened == ["Safari"])
        #expect(runs.isEmpty)
        #expect(!view.choosingAction)
    }

    @Test func aLongListScrollsInsideTheLauncher() throws {
        defer { view.closeActions() }
        offer((1...30).map { "App \($0)" })
        press(kVK_ANSI_K, "k", [.command])
        let menu = try #require(view.actionPanel)
        #expect(menu.rows[1].accessibilityPerformPress())
        view.layoutSubtreeIfNeeded()
        #expect(menu.rows.count == 30)
        #expect(view.frame.size == NSSize(width: 760, height: 476))
        #expect(menu.glass.frame.maxY == view.bounds.maxY - 10)
        let header = menu.glass.convert(menu.header.bounds, from: menu.header)
        #expect(menu.glass.bounds.contains(header))
    }

    private func offer(_ names: [String]) {
        view.actions = { [weak self] _ in
            [
                .init("Open", keys: ["↵"]),
                .init("Open With…") {
                    names.map { name in
                        ActionChoice(name, icon: NSImage(size: NSSize(width: 16, height: 16))) {
                            self?.opened.append(name)
                        }
                    }
                },
            ]
        }
    }

    private func type(_ text: String, in menu: ActionPanel) {
        menu.field.stringValue = text
        menu.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
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
