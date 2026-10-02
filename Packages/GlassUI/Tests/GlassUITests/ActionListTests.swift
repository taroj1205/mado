import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct ActionListTests {
    @Test func groupsAreDividedByAnInsetLine() throws {
        let list = ActionList()
        list.frame = NSRect(x: 0, y: 0, width: 304, height: 400)
        let rows = ["Open", "Copy Path", "Add to Favourites", "Quit Application"].map(row)
        list.show(rows, groups: [0, 0, 1, 2], label: "Actions for Chess")
        let stack = try #require(list.documentView as? NSStackView)
        #expect(
            stack.arrangedSubviews.map { $0 is ActionRow } == [
                true, true, false, true, false, true,
            ])
        #expect(stack.accessibilityLabel() == "Actions for Chess")
        list.layoutSubtreeIfNeeded()
        let line = try #require(stack.arrangedSubviews[2] as? NSBox)
        #expect(line.boxType == .separator)
        #expect(line.frame.minX == 10)
        #expect(line.frame.width == stack.frame.width - 20)

        let quit = row("Quit Application")
        list.show([quit], groups: [2], label: "Actions for Chess")
        #expect(stack.arrangedSubviews == [quit])
    }

    @Test func theSelectionScrollsIntoViewAndANewListStartsAtTheTop() {
        let list = ActionList()
        list.frame = NSRect(x: 0, y: 0, width: 304, height: 100)
        let rows = (1...30).map { row("App \($0)") }
        list.show(rows, groups: rows.map { _ in 0 }, label: "Open With")
        list.layoutSubtreeIfNeeded()
        let visible = { list.contentView.documentVisibleRect }
        #expect(visible().contains(rows[0].frame))
        for _ in 1...30 {
            list.moveSelection(by: 1)
        }
        #expect(rows.map(\.isSelected) == Array(repeating: false, count: 29) + [true])
        #expect(visible().contains(rows[29].frame))
        #expect(!visible().contains(rows[0].frame))

        let again = (1...30).map { row("App \($0)") }
        list.show(again, groups: again.map { _ in 0 }, label: "Open With")
        list.layoutSubtreeIfNeeded()
        #expect(again[0].isSelected)
        #expect(visible().contains(again[0].frame))
    }

    private func row(_ title: String) -> ActionRow {
        ActionRow(title: title, keys: [], icon: nil, isDestructive: false)
    }
}
