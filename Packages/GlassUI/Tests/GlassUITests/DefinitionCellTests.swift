import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct DefinitionCellTests {
    private static let width: CGFloat = 744
    private let open = ResultList.Item(
        id: "dictionary.open", title: "Open in Dictionary",
        subtitle: "New Oxford American Dictionary", kind: "", symbol: "book.closed",
        action: "Open in Dictionary", tint: .brown, shortcut: ["↵"])
    private let copy = ResultList.Item(
        id: "dictionary.copy", title: "Copy Definition", subtitle: "", kind: "",
        symbol: "doc.on.doc", action: "Copy Definition", shortcut: ["⌘", "↵"])

    private func card(
        text: String = "Lasting for a very short time.", similar: [String] = ["fleeting", "brief"],
        opposite: [String] = ["permanent"]
    ) -> ResultList.Card {
        ResultList.Card(
            title: "ephemeral", detail: "/əˈfem(ə)rəl/ · adjective", text: text,
            similar: similar.map { .init(title: $0, query: "define \($0)") }, opposite: opposite)
    }

    private func chips(in cell: DefinitionCell) -> [NSButton] {
        buttons(in: cell.similar)
    }

    private func buttons(in view: NSView) -> [NSButton] {
        view.subviews.flatMap { ($0 as? NSButton).map { [$0] } ?? buttons(in: $0) }
    }

    @Test func theCardSitsAboveTheDictionaryRowsAndIsNotSelectable() throws {
        let list = ResultList()
        list.frame = NSRect(x: 0, y: 0, width: Self.width, height: 415)
        let card = card()
        list.sections = [.init(title: "Dictionary", items: [open, copy], card: card)]
        list.layoutSubtreeIfNeeded()
        #expect(list.rows == [.card(card), .header("Dictionary"), .item(open), .item(copy)])
        #expect(list.selectedItem == open)
        list.selectPrevious()
        #expect(list.selectedItem == open)
        let cell = try #require(
            list.table.view(atColumn: 0, row: 0, makeIfNecessary: false) as? DefinitionCell)
        #expect(cell.headword.stringValue == "ephemeral")
        #expect(cell.detail.stringValue == "/əˈfem(ə)rəl/ · adjective")
        #expect(cell.definition.stringValue == "Lasting for a very short time.")
        #expect(chips(in: cell).map(\.title) == ["fleeting", "brief"])
        #expect(cell.opposite.stringValue == "Opposite: permanent")
        let height = DefinitionCell.height(for: card, width: Self.width)
        #expect(list.table.rect(ofRow: 0).height == height + ResultList.rowGap)
    }

    @Test func clickingASimilarWordPicksItsQuery() throws {
        let cell = DefinitionCell()
        var picks: [String] = []
        cell.onPick = { picks.append($0) }
        cell.show(card(), width: Self.width)
        try #require(chips(in: cell).last).performClick(nil)
        #expect(picks == ["define brief"])
        #expect(!chips(in: cell).contains { !$0.refusesFirstResponder })
    }

    @Test func theCardGrowsWithTheDefinitionUpToThreeLinesAndDropsEmptyParts() {
        let short = DefinitionCell.height(for: card(), width: Self.width)
        let long = DefinitionCell.height(
            for: card(text: String(repeating: "lasting for a very short time ", count: 20)),
            width: Self.width)
        let longer = DefinitionCell.height(
            for: card(text: String(repeating: "lasting for a very short time ", count: 60)),
            width: Self.width)
        let bare = DefinitionCell.height(
            for: card(similar: [], opposite: []), width: Self.width)
        #expect(long > short)
        #expect(longer == long)
        #expect(bare < short)
    }

    @Test func similarWordsThatDoNotFitAreLeftOut() {
        let cell = DefinitionCell(frame: NSRect(x: 0, y: 0, width: Self.width, height: 160))
        let words = (1...5).map { "an unusually long similar phrase \($0)" }
        cell.show(card(similar: words), width: Self.width)
        cell.layoutSubtreeIfNeeded()
        let visible = cell.similar.views.filter { !cell.similar.detachedViews.contains($0) }
        #expect(visible.count < words.count + 1)
        for chip in visible {
            #expect(cell.convert(chip.bounds, from: chip).maxX <= cell.card.frame.maxX)
        }
    }

    @Test func dictionaryRowsShowKeycapsInsteadOfAKindAndATintedTile() {
        let cell = ResultCell(frame: NSRect(x: 0, y: 0, width: Self.width, height: 42))
        cell.show(copy)
        cell.layoutSubtreeIfNeeded()
        let keys = cell.convert(cell.shortcut.bounds, from: cell.shortcut)
        #expect(abs(keys.maxX - (Self.width - 12)) < 1)
        #expect(cell.kind.isHidden)
        #expect(cell.shortcut.views.compactMap { ($0 as? Keycap)?.name.stringValue } == ["⌘", "↵"])
        #expect(cell.tile.fillColor == ResultRowView.fill)
        cell.show(open)
        #expect(cell.tile.fillColor == .brown)
        #expect(cell.symbol.contentTintColor == .white)
        cell.show(
            .init(
                id: "a", title: "Safari", subtitle: "", kind: "Application", symbol: "", action: "")
        )
        cell.layoutSubtreeIfNeeded()
        let kind = cell.kind.alignmentRect(
            forFrame: cell.convert(cell.kind.bounds, from: cell.kind))
        #expect(abs(kind.maxX - (Self.width - 12)) < 1)
        #expect(!cell.kind.isHidden)
        #expect(cell.shortcut.isHidden)
        #expect(cell.symbol.contentTintColor == .labelColor)
    }

    @Test func pickingAWordReplacesTheQueryAndSearchesAgain() throws {
        let view = LauncherView()
        view.frame = NSRect(x: 0, y: 0, width: 760, height: 476)
        var queries: [String] = []
        view.onQuery = { queries.append($0) }
        view.field.stringValue = "define ephemeral"
        view.results.sections = [.init(title: "Dictionary", items: [open, copy], card: card())]
        view.layoutSubtreeIfNeeded()
        let cell = try #require(
            view.results.table.view(atColumn: 0, row: 0, makeIfNecessary: false)
                as? DefinitionCell)
        try #require(chips(in: cell).first).performClick(nil)
        #expect(view.field.stringValue == "define fleeting")
        #expect(queries == ["define fleeting"])
    }
}
