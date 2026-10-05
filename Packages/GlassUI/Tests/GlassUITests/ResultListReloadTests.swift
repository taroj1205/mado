import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite(.silentWindows) struct ResultListReloadTests {
    @Test func newResultsReuseTheVisibleCells() throws {
        let list = shown([results("A", "B", "C")])
        let before = try #require(list.table.view(atColumn: 0, row: 1, makeIfNecessary: false))
        list.sections = [results("X", "Y", "Z")]
        list.layoutSubtreeIfNeeded()
        let after = try #require(
            list.table.view(atColumn: 0, row: 1, makeIfNecessary: false) as? ResultCell)
        #expect(after === before)
        #expect(after.title.stringValue == "X")
    }

    @Test func rowsFollowTheNewResultsHeightsAndCorners() throws {
        let list = shown([results("A", "B", "C"), results("D", "E", "F")])
        let window = NSWindow(
            contentRect: list.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.contentView = list
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        let answer = ResultList.Item(
            id: "calculator", title: "12 ÷ 4", subtitle: "", kind: "Calculator", symbol: "",
            action: "Copy Answer", answer: .init(value: "3", detail: ""))
        list.sections = [.init(title: "Calculator", items: [answer]), results("A", "B")]
        RunLoop.main.run(until: .now + 0.3)
        #expect(list.table.numberOfRows == 5)
        #expect(list.table.rect(ofRow: 1).height == ResultList.answerHeight + ResultList.rowGap)
        for row in 0..<list.table.numberOfRows {
            let cell = try #require(list.table.view(atColumn: 0, row: row, makeIfNecessary: false))
            #expect(cell.frame.height == list.table.rect(ofRow: row).height - ResultList.rowGap)
        }
        let corner = try #require(
            list.table.rowView(atRow: 1, makeIfNecessary: false) as? ResultRowView)
        #expect(corner.radius == AnswerCell.radius)

        list.sections = [results("A")]
        #expect(list.table.numberOfRows == 2)
        list.sections = [results("A", "B", "C", "D", "E")]
        #expect(list.table.numberOfRows == 6)
        #expect(list.selectedItem?.id == "A")
    }

    private func results(_ titles: String...) -> ResultList.Section {
        .init(
            title: "Results",
            items: titles.map { title in
                .init(
                    id: title, title: title, subtitle: "", kind: "Command", symbol: "star",
                    action: "Run Command")
            })
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
