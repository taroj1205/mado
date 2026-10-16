import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct ResultListMoreTests {
    @Test func asksForMoreOnceWhenTheSelectionNearsTheEnd() {
        let list = shown(count: 30, hasMore: true)
        var asked = 0
        list.onNearEnd = { asked += 1 }

        for _ in 0..<10 {
            list.selectNext()
        }
        #expect(asked == 0)
        for _ in 0..<20 {
            list.selectNext()
        }
        #expect(asked == 1)
    }

    @Test func staysQuietWhenNothingIsLeftToLoad() {
        let list = shown(count: 30, hasMore: false)
        var asked = 0
        list.onNearEnd = { asked += 1 }

        for _ in 0..<30 {
            list.selectNext()
        }
        #expect(asked == 0)
    }

    @Test func keepsTheSelectionAndScrollPositionWhenMoreArrives() {
        let list = shown(count: 30, hasMore: true)
        var asked = 0
        list.onNearEnd = { asked += 1 }
        for _ in 0..<25 {
            list.selectNext()
        }
        list.contentView.setBoundsOrigin(NSPoint(x: 0, y: 40))
        let scrolled = list.contentView.bounds.origin

        list.sections = [section(count: 60, hasMore: true)]

        #expect(list.selectedItem?.id == "25")
        #expect(list.contentView.bounds.origin == scrolled)
        #expect(list.rows.count == 61)
        for _ in 0..<40 {
            list.selectNext()
        }
        #expect(asked == 2)
    }

    @Test func aNewQueryForgetsAPendingRequestForMore() {
        let launcher = LauncherView()
        var asked = 0
        launcher.results.onNearEnd = { asked += 1 }
        launcher.show([section(count: 30, hasMore: true)])
        launcher.layoutSubtreeIfNeeded()
        for _ in 0..<25 {
            launcher.results.selectNext()
        }
        #expect(asked == 1)

        launcher.endBrowsing()
        launcher.show([section(count: 30, hasMore: true)])

        #expect(launcher.results.selectedItem?.id == "0")
    }

    private func section(count: Int, hasMore: Bool) -> ResultList.Section {
        var section = ResultList.Section(
            title: "Files",
            items: (0..<count).map { index in
                .init(
                    id: "\(index)", title: "File \(index)", subtitle: "", kind: "File",
                    symbol: "", action: "Open")
            })
        section.hasMore = hasMore
        return section
    }

    private func shown(count: Int, hasMore: Bool) -> ResultList {
        let list = ResultList()
        list.reducesMotion = { true }
        list.frame = NSRect(x: 0, y: 0, width: 744, height: 415)
        list.sections = [section(count: count, hasMore: hasMore)]
        list.layoutSubtreeIfNeeded()
        return list
    }
}
