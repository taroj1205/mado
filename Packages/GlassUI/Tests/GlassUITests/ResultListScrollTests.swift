import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct ResultListScrollTests {
    private var manyItems: [ResultList.Section] {
        [.init(title: "Applications", items: (0..<500).map(item))]
    }

    @Test func movingKeepsTheNextRowInViewToo() {
        let list = shown(manyItems)
        let visible = list.table.rows(in: list.contentView.documentVisibleRect)
        for _ in 0..<visible.length {
            list.selectNext()
        }
        let selected = list.table.selectedRow
        #expect(list.contentView.documentVisibleRect.contains(list.table.rect(ofRow: selected + 1)))
        for _ in 0..<visible.length / 2 {
            list.selectNext()
        }
        let lower = list.contentView.bounds.minY
        list.selectPrevious()
        #expect(list.contentView.bounds.minY == lower)
        for _ in 0..<visible.length {
            list.selectPrevious()
        }
        let top = list.table.rect(ofRow: list.table.selectedRow - 1).minY
        #expect(list.contentView.bounds.minY + ResultList.topInset == top)
    }

    @Test func arrowsGlideTheListWithoutLeavingTheSelectionBehind() {
        let list = shown(manyItems)
        list.reducesMotion = { false }
        let visible = list.table.rows(in: list.contentView.documentVisibleRect).length
        var hidden = 0
        for _ in 0..<visible + 5 {
            list.selectNext()
            if !unobscured(list).contains(list.table.rect(ofRow: list.table.selectedRow)) {
                hidden += 1
            }
        }
        #expect(hidden == 0)
        let heading = list.heading
        #expect(heading != nil)
        #expect(list.contentView.bounds.minY < heading?.y ?? 0)
        let deadline = Date(timeIntervalSinceNow: 10)
        while list.heading != nil, list.contentView.bounds.origin != heading, Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        }
        #expect(list.contentView.bounds.origin == heading)
        let next = list.table.rect(ofRow: list.table.selectedRow + 1)
        #expect(list.contentView.documentVisibleRect.contains(next))
    }

    @Test func newResultsAndScrollingByHandStopTheGlide() throws {
        let list = shown(manyItems)
        list.reducesMotion = { false }
        for _ in 0..<30 {
            list.selectNext()
        }
        list.sections = manyItems
        #expect(list.heading == nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        #expect(list.contentView.bounds.minY == -ResultList.topInset)

        for _ in 0..<30 {
            list.selectNext()
        }
        let wheel = try #require(
            CGEvent(
                scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: 0, wheel2: 0,
                wheel3: 0
            )
            .flatMap(NSEvent.init))
        list.scrollWheel(with: wheel)
        #expect(list.heading == nil)
        let stopped = list.contentView.bounds.minY
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        #expect(list.contentView.bounds.minY == stopped)
    }

    private func unobscured(_ list: ResultList) -> NSRect {
        let bounds = list.contentView.bounds
        return NSRect(
            x: bounds.minX, y: bounds.minY + list.contentInsets.top, width: bounds.width,
            height: bounds.height - list.contentInsets.top - list.contentInsets.bottom)
    }

    private func item(_ index: Int) -> ResultList.Item {
        .init(
            id: "\(index)", title: "App \(index)", subtitle: "", kind: "Command",
            symbol: "star", action: "Run Command")
    }

    private func shown(_ sections: [ResultList.Section]) -> ResultList {
        let list = ResultList()
        list.reducesMotion = { true }
        list.frame = NSRect(x: 0, y: 0, width: 744, height: 415)
        list.sections = sections
        list.layoutSubtreeIfNeeded()
        return list
    }
}
