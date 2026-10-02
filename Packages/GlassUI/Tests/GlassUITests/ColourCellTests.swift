import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct ColourCellTests {
    private let card = ResultList.ColourCard(
        swatch: NSColor(srgbRed: 10 / 255, green: 132 / 255, blue: 1, alpha: 1), hex: "#0A84FF",
        rgb: "rgb(10, 132, 255)", hsl: "hsl(210, 100%, 52%)", closest: "System Blue",
        onWhite: "3.6 : 1", onBlack: "5.7 : 1")
    private let copies: [ResultList.Item] = [
        ("hex", "#0A84FF", ["↵"]), ("rgb", "rgb(10, 132, 255)", ["⌘", "1"]),
        ("hsl", "hsl(210, 100%, 52%)", ["⌘", "2"]),
    ]
    .map { id, value, keys in
        .init(
            id: id, title: "Copy \(id)", subtitle: value, kind: "Colour", symbol: "doc.on.doc",
            action: "Copy \(id)", keys: keys)
    }

    @Test func theCardSitsAboveCopyAsAndCannotBeSelected() throws {
        let list = shown([.init(title: "Copy as", items: copies, colour: card)])
        #expect(
            Array(list.rows.prefix(3)) == [.colour(card), .header("Copy as"), .item(copies[0])])
        #expect(list.table.rect(ofRow: 0).height == ResultList.colourHeight + ResultList.rowGap)
        #expect(list.table.delegate?.tableView?(list.table, shouldSelectRow: 0) == false)
        #expect(list.selectedItem == copies[0])
        list.selectPrevious()
        #expect(list.selectedItem == copies[0])

        let cell = try #require(
            list.table.view(atColumn: 0, row: 0, makeIfNecessary: false) as? ColourCell)
        cell.layoutSubtreeIfNeeded()
        #expect(cell.hex.stringValue == "#0A84FF")
        #expect(cell.rgb.stringValue == "rgb(10, 132, 255)")
        #expect(cell.hsl.stringValue == "hsl(210, 100%, 52%)")
        #expect(cell.closest.stringValue == "Closest system colour: System Blue")
        #expect(cell.onWhite.stringValue == "On white 3.6 : 1")
        #expect(cell.onBlack.stringValue == "On black 5.7 : 1")
        #expect(cell.swatch.fillColor == card.swatch)
        #expect(cell.card.frame == NSRect(x: 4, y: 4, width: cell.bounds.width - 8, height: 130))
        let swatch = cell.convert(cell.swatch.bounds, from: cell.swatch)
        #expect(swatch.size == NSSize(width: 96, height: 96))
        let columns = [cell.hex, cell.rgb, cell.hsl].map { cell.convert($0.bounds, from: $0) }
        #expect(swatch.maxX < columns[0].minX)
        #expect(columns[0].maxX < columns[1].minX)
        #expect(columns[1].maxX < columns[2].minX)
        #expect(columns.allSatisfy { $0.midY == columns[0].midY })
        #expect(cell.convert(cell.closest.bounds, from: cell.closest).maxY < columns[0].minY)
    }

    @Test func movingBackToTheFirstCopyRowScrollsTheCardIntoView() {
        let results = (0..<20).map { index in
            ResultList.Item(
                id: "\(index)", title: "App \(index)", subtitle: "", kind: "Application",
                symbol: "", action: "Open")
        }
        let list = shown([
            .init(title: "Copy as", items: copies, colour: card),
            .init(title: "Results", items: results),
        ])
        for _ in 0..<22 {
            list.selectNext()
        }
        #expect(list.contentView.bounds.minY > 0)
        for _ in 0..<22 {
            list.selectPrevious()
        }
        #expect(list.selectedItem == copies[0])
        #expect(list.contentView.bounds.minY == -ResultList.topInset)
    }

    @Test func copyRowsShowTheirShortcutWhereTheKindWouldBe() {
        let cell = ResultCell(frame: NSRect(x: 0, y: 0, width: 744, height: 42))
        cell.show(copies[1])
        let keys = cell.accessory.arrangedSubviews.compactMap { ($0 as? Keycap)?.name.stringValue }
        #expect(keys == ["⌘", "1"])
        cell.layoutSubtreeIfNeeded()
        #expect(cell.accessory.frame.maxX == cell.bounds.maxX - 12)
        #expect(cell.accessory.frame.width < 60)
        cell.show(
            .init(
                id: "sleep", title: "Sleep", subtitle: "", kind: "Command", symbol: "moon",
                action: "Run Command"))
        #expect(cell.accessory.arrangedSubviews == [cell.kind])
    }

    @Test func voiceOverReadsTheCardAsOneSentence() {
        let cell = ColourCell()
        cell.show(card)
        #expect(
            cell.accessibilityLabel()
                == "Colour #0A84FF, rgb(10, 132, 255), hsl(210, 100%, 52%), "
                + "closest system colour System Blue, on white 3.6 : 1, on black 5.7 : 1")
        #expect(cell.accessibilityChildren()?.isEmpty == true)
    }

    private func shown(_ sections: [ResultList.Section]) -> ResultList {
        let list = ResultList()
        list.frame = NSRect(x: 0, y: 0, width: 744, height: 415)
        list.sections = sections
        list.layoutSubtreeIfNeeded()
        return list
    }
}
