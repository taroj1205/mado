import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct ResultListChecksTests {
    private let list = ResultList()
    private var changes: [[String]] = []

    init() {
        list.reducesMotion = { true }
        list.compact = true
        list.update(
            [
                .init(
                    title: "Today",
                    items: ["a", "b", "c", "d"].map { item($0) } + [item("image", checkable: false)]
                )
            ], keepingSelectionOf: nil)
    }

    private func item(_ id: String, checkable: Bool = true) -> ResultList.Item {
        .init(
            id: id, title: id, subtitle: "", kind: "Text", symbol: "text.alignleft",
            action: "Paste",
            isCheckable: checkable)
    }

    @Test func shiftMovesCheckTheRowsItLeavesAndEnters() {
        #expect(list.extendChecks(by: 1))
        #expect(list.selectedItem?.id == "b")
        #expect(list.checked == ["a", "b"])
        #expect(list.extendChecks(by: 1))
        #expect(list.checked == ["a", "b", "c"])
    }

    @Test func shiftingBackUnchecksTheRowItLeaves() {
        list.extendChecks(by: 1)
        list.extendChecks(by: 1)
        list.extendChecks(by: -1)
        #expect(list.selectedItem?.id == "b")
        #expect(list.checked == ["a", "b"])
    }

    @Test func shiftIntoANonCheckableRowMovesWithoutChecking() {
        for _ in 0..<3 { list.extendChecks(by: 1) }
        #expect(list.checked == ["a", "b", "c", "d"])
        #expect(list.extendChecks(by: 1))
        #expect(list.selectedItem?.id == "image")
        #expect(list.checked == ["a", "b", "c", "d"])
    }

    @Test func shiftOnANonCheckableRowIsLeftToTheField() {
        list.selectNext()
        list.selectNext()
        list.selectNext()
        list.selectNext()
        #expect(list.selectedItem?.id == "image")
        #expect(!list.extendChecks(by: -1))
        #expect(list.checked.isEmpty)
    }

    @Test func checksKeepTheOrderTheyWereMadeIn() {
        list.selectNext()
        list.selectNext()
        list.extendChecks(by: -1)
        #expect(list.checked == ["c", "b"])
    }

    @Test func clearingDropsEveryCheck() {
        var notified: [[String]] = []
        list.onCheck = { notified.append($0) }
        list.extendChecks(by: 1)
        list.clearChecks()
        #expect(list.checked.isEmpty)
        #expect(notified == [["a", "b"], []])
    }

    @Test func aReloadKeepsChecksOnRowsThatAreStillThereAndReportsTheLoss() {
        var notified: [[String]] = []
        list.extendChecks(by: 1)
        list.extendChecks(by: 1)
        list.onCheck = { notified.append($0) }
        list.update(
            [.init(title: "Today", items: [item("c"), item("b")])], keepingSelectionOf: nil)
        #expect(list.checked == ["b", "c"])
        #expect(notified == [["b", "c"]])
        list.update(
            [.init(title: "Today", items: [item("c"), item("b")])], keepingSelectionOf: nil)
        #expect(notified.count == 1)
    }

    @Test func checkedRowsShowACircleOnEveryCheckableRow() throws {
        list.extendChecks(by: 1)
        let first = try #require(
            list.table.view(atColumn: 0, row: 1, makeIfNecessary: true) as? GlyphCell)
        #expect(!first.check.isHidden)
        #expect(first.check.isChecked)
        let other = try #require(
            list.table.view(atColumn: 0, row: 3, makeIfNecessary: true) as? GlyphCell)
        #expect(!other.check.isHidden)
        #expect(!other.check.isChecked)
        let image = try #require(
            list.table.view(atColumn: 0, row: 5, makeIfNecessary: true) as? GlyphCell)
        #expect(image.check.isHidden)
        list.clearChecks()
        let cleared = try #require(
            list.table.view(atColumn: 0, row: 1, makeIfNecessary: true) as? GlyphCell)
        #expect(cleared.check.isHidden)
    }
}
