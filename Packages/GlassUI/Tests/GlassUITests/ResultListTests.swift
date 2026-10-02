import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct ResultListTests {
    private var manyItems: [ResultList.Section] {
        [
            .init(title: "Applications", items: (0..<500).map { item("App \($0)") }),
            .init(title: "Commands", items: (0..<500).map { item("Command \($0)") }),
        ]
    }

    @Test func sectionsBecomeAHeaderRowFollowedByTheirItems() {
        let safari = item("Safari")
        let notes = item("Notes")
        let sleep = item("Sleep")
        let rows = ResultList.rows(for: [
            .init(title: "Applications", items: [safari, notes]),
            .init(title: "Empty", items: []),
            .init(title: "Commands", items: [sleep]),
        ])
        #expect(
            rows == [
                .header("Applications"), .item(safari), .item(notes),
                .header("Commands"), .item(sleep),
            ])
    }

    @Test func aNoticeSitsAboveItsSectionAndCannotBeSelected() throws {
        let notice = ResultList.Notice(title: "No matches for “xyz”", detail: "Try these.")
        let web = item("Search Google")
        let list = shown([.init(title: "Use “xyz” with…", items: [web], notice: notice)])
        #expect(list.rows == [.notice(notice), .header("Use “xyz” with…"), .item(web)])
        #expect(list.table.rect(ofRow: 0).height == ResultList.noticeHeight + ResultList.rowGap)
        #expect(list.table.delegate?.tableView?(list.table, shouldSelectRow: 0) == false)
        #expect(list.selectedItem == web)
        list.selectPrevious()
        #expect(list.selectedItem == web)
        let cell = try #require(
            list.table.view(atColumn: 0, row: 0, makeIfNecessary: false) as? NoticeCell)
        #expect(cell.title.stringValue == notice.title)
        #expect(cell.detail.stringValue == notice.detail)
    }

    @Test func rowsAreFortyTwoPointsAndHeadersCannotBeSelected() {
        let list = shown([.init(title: "Commands", items: [item("A"), item("B")])])
        #expect(list.table.numberOfRows == 3)
        #expect(list.table.rect(ofRow: 0).height == ResultList.headerHeight + ResultList.rowGap)
        #expect(list.table.rect(ofRow: 1).height == ResultList.rowHeight + ResultList.rowGap)
        #expect(list.table.delegate?.tableView?(list.table, shouldSelectRow: 0) == false)
        #expect(list.table.delegate?.tableView?(list.table, shouldSelectRow: 1) == true)
    }

    @Test func newResultsSelectTheFirstItemAndScrollToTheTop() {
        let list = shown(manyItems)
        list.table.scrollRowToVisible(list.table.numberOfRows - 1)
        list.table.selectRowIndexes([5], byExtendingSelection: false)
        list.sections = [.init(title: "Results", items: [item("A"), item("B")])]
        #expect(list.table.selectedRow == 1)
        #expect(list.contentView.bounds.minY == -ResultList.topInset)
    }

    @Test func anUpdateCanKeepTheSelectedItemIfItIsStillThere() {
        let list = shown([.init(title: "Results", items: [item("A"), item("B"), item("C")])])
        list.selectNext()
        list.update(
            [.init(title: "Results", items: [item("New"), item("A"), item("B")])],
            keepingSelectionOf: "B")
        #expect(list.selectedItem?.id == "B")
        list.update(
            [.init(title: "Results", items: [item("New"), item("A")])], keepingSelectionOf: "B")
        #expect(list.selectedItem?.id == "New")
        list.update(
            [.init(title: "Results", items: [item("X"), item("A")])], keepingSelectionOf: nil)
        #expect(list.selectedItem?.id == "X")
    }

    @Test func selectionIsAGreyFillThatLeavesTheSearchFieldFocused() throws {
        let list = shown([.init(title: "Commands", items: [item("A")])])
        let row = try #require(list.table.rowView(atRow: 1, makeIfNecessary: false))
        #expect(row is ResultRowView)
        #expect(row.isSelected)
        #expect(!list.table.acceptsFirstResponder)
        let image = try #require(row.bitmapImageRepForCachingDisplay(in: row.bounds))
        row.cacheDisplay(in: row.bounds, to: image)
        let middle = image.pixelsWide / 2
        #expect(image.colorAt(x: middle, y: image.pixelsHigh / 2)?.alphaComponent ?? 0 > 0)
        #expect(image.colorAt(x: middle, y: image.pixelsHigh - 1)?.alphaComponent == 0)
    }

    @Test func selectionGreyFollowsTheTheme() throws {
        let dark = try #require(NSAppearance(named: .darkAqua))
        let light = try #require(NSAppearance(named: .aqua))
        var alphas: [CGFloat] = []
        for appearance in [dark, light] {
            appearance.performAsCurrentDrawingAppearance {
                alphas.append(ResultRowView.fill.usingColorSpace(.sRGB)?.alphaComponent ?? 0)
            }
        }
        #expect(alphas[0] > alphas[1])
        #expect(alphas[1] > 0)
    }

    @Test func cellsShowTheItem() throws {
        let list = shown([
            .init(
                title: "Commands",
                items: [
                    .init(
                        id: "sleep", title: "Sleep", subtitle: "System", kind: "Command",
                        symbol: "moon", action: "Run Command")
                ])
        ])
        let cell = try #require(list.table.view(atColumn: 0, row: 1, makeIfNecessary: false))
        let result = try #require(cell as? ResultCell)
        result.layoutSubtreeIfNeeded()
        #expect(result.title.stringValue == "Sleep")
        #expect(result.subtitle.stringValue == "System")
        #expect(result.kind.stringValue == "Command")
        #expect(result.symbol.image != nil)
        #expect(result.tile.frame.width == ResultCell.tileSize)
        #expect(result.tile.frame.height == ResultCell.tileSize)
    }

    @Test func voiceOverReadsARowAsItsNameKindAndSubtitle() {
        let cell = ResultCell()
        cell.show(
            .init(
                id: "sleep", title: "Sleep", subtitle: "System", kind: "Command",
                symbol: "moon", action: "Run Command"))
        #expect(cell.accessibilityLabel() == "Sleep, Command, System")
        #expect(cell.accessibilityChildren()?.isEmpty == true)

        cell.show(item("Notes"))
        #expect(cell.accessibilityLabel() == "Notes, Command")
    }

    @Test func appIconsReplaceTheTileUntilTheCellShowsASymbolAgain() {
        let cell = ResultCell()
        let icon = NSImage(size: NSSize(width: 32, height: 32))
        cell.show(
            .init(
                id: "/Applications/Safari.app", title: "Safari", subtitle: "",
                kind: "Application", symbol: "", action: "Open Application", icon: icon))
        #expect(cell.symbol.image === icon)
        #expect(cell.tile.borderWidth == 0)

        cell.show(item("Sleep"))
        #expect(cell.symbol.image !== icon)
        #expect(cell.tile.borderWidth > 0)
        #expect(cell.tile.fillColor == ResultRowView.fill)
    }

    @Test func arrowsSkipHeadersAndStopAtTheEnds() {
        let list = shown([
            .init(title: "Applications", items: [item("A"), item("B")]),
            .init(title: "Commands", items: [item("C")]),
        ])
        var titles: [String?] = []
        for move in [list.selectNext, list.selectNext, list.selectNext] {
            move()
            titles.append(list.selectedItem?.title)
        }
        for move in [list.selectPrevious, list.selectPrevious, list.selectPrevious] {
            move()
            titles.append(list.selectedItem?.title)
        }
        #expect(titles == ["B", "C", "C", "B", "A", "A"])
        #expect(list.table.selectedRow == 1)
    }

    @Test func movingKeepsTheSelectionAndItsSectionHeaderInView() {
        let list = shown(manyItems)
        for _ in 0..<40 {
            list.selectNext()
        }
        #expect(list.contentView.documentVisibleRect.contains(list.table.rect(ofRow: 41)))
        for _ in 0..<40 {
            list.selectPrevious()
        }
        #expect(list.table.selectedRow == 1)
        #expect(list.contentView.bounds.minY == -ResultList.topInset)
    }

    @Test func selectionChangesAreReported() {
        let list = shown([.init(title: "Commands", items: [item("A"), item("B")])])
        var selected: [String?] = []
        var moves = 0
        list.onSelect = { selected.append($0?.title) }
        list.onMove = { moves += 1 }
        list.selectNext()
        list.table.selectRowIndexes([1], byExtendingSelection: false)
        list.table.sendAction(list.table.action, to: list.table.target)
        list.sections = [.init(title: "Results", items: [item("C")])]
        list.sections = []
        #expect(selected == ["B", "A", "C", nil])
        #expect(moves == 1)
    }

    @Test func emptyResultsHaveNoSelectedItem() {
        let list = shown([])
        list.selectNext()
        list.selectPrevious()
        #expect(list.selectedItem == nil)
    }

    @Test func clickingEmptySpaceKeepsTheSelection() {
        let list = shown([.init(title: "Results", items: [item("A"), item("B")])])
        list.table.deselectAll(nil)
        #expect(list.selectedItem?.id == "A")
    }

    @Test func aThousandRowsOnlyBuildTheVisibleViews() {
        let list = shown(manyItems)
        let visible = list.table.rows(in: list.contentView.documentVisibleRect)
        var built = 0
        list.table.enumerateAvailableRowViews { _, _ in built += 1 }
        #expect(list.table.numberOfRows == 1_002)
        #expect(built <= visible.length)
    }

    private func item(_ title: String) -> ResultList.Item {
        .init(
            id: title, title: title, subtitle: "", kind: "Command", symbol: "star",
            action: "Run Command")
    }

    private func shown(_ sections: [ResultList.Section]) -> ResultList {
        let list = ResultList()
        list.frame = NSRect(x: 0, y: 0, width: 744, height: 415)
        list.sections = sections
        list.layoutSubtreeIfNeeded()
        return list
    }
}
