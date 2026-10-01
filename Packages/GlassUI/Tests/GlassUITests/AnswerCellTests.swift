import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct AnswerCellTests {
    @Test func anAnswerIsATallSelectedCardWithTheResultOnTheRight() throws {
        let answer = ResultList.Item(
            id: "calculator", title: "54 × 1.15", subtitle: "Fifty-four times one point one five",
            kind: "Calculator", symbol: "", action: "Copy Answer",
            answer: .init(value: "62.1", detail: "Sixty-two point one"))
        let search = ResultList.Item(
            id: "fallback.web", title: "Search Google", subtitle: "google.com", kind: "Web",
            symbol: "globe", action: "Search Google")
        let list = ResultList()
        list.frame = NSRect(x: 0, y: 0, width: 744, height: 415)
        list.sections = [
            .init(title: "Calculator", items: [answer]),
            .init(title: "Use “54 * 1.15” with…", items: [search]),
        ]
        list.layoutSubtreeIfNeeded()
        #expect(list.table.rect(ofRow: 1).height == ResultList.answerHeight + ResultList.rowGap)
        #expect(list.table.rect(ofRow: 3).height == ResultList.rowHeight + ResultList.rowGap)
        #expect(list.selectedItem == answer)
        let cell = try #require(
            list.table.view(atColumn: 0, row: 1, makeIfNecessary: false) as? AnswerCell)
        cell.layoutSubtreeIfNeeded()
        #expect(cell.expression.stringValue == "54 × 1.15")
        #expect(cell.expressionDetail.stringValue == "Fifty-four times one point one five")
        #expect(cell.result.stringValue == "62.1")
        #expect(cell.resultDetail.stringValue == "Sixty-two point one")
        let expression = cell.convert(cell.expression.bounds, from: cell.expression)
        let result = cell.convert(cell.result.bounds, from: cell.result)
        #expect(expression.maxX < cell.arrow.frame.minX)
        #expect(result.minX > cell.arrow.frame.maxX)
        #expect(abs(expression.midY - result.midY) < 4)

        let row = try #require(list.table.rowView(atRow: 1, makeIfNecessary: false))
        let image = try #require(row.bitmapImageRepForCachingDisplay(in: row.bounds))
        row.cacheDisplay(in: row.bounds, to: image)
        let scale = CGFloat(image.pixelsHigh) / row.bounds.height
        let cardBottom = Int((ResultList.answerHeight - ResultList.rowHeight) * scale)
        #expect(image.colorAt(x: image.pixelsWide / 2, y: cardBottom)?.alphaComponent ?? 0 > 0)
        #expect(
            image.colorAt(x: image.pixelsWide / 2, y: image.pixelsHigh - 1)?.alphaComponent == 0)
    }

    @Test func longAnswersStayOnOneLineInsideTheirColumn() {
        let cell = AnswerCell(frame: NSRect(x: 0, y: 0, width: 744, height: 116))
        let labels = [cell.expression, cell.expressionDetail, cell.result, cell.resultDetail]
        var heights: [CGFloat] = []
        for text in ["1", String(repeating: "123,456,789 ", count: 10)] {
            cell.show(
                .init(
                    id: "calculator", title: text, subtitle: text, kind: "Calculator", symbol: "",
                    action: "Copy Answer", answer: .init(value: text, detail: text)))
            cell.layoutSubtreeIfNeeded()
            heights += labels.map(\.frame.height)
        }
        #expect(heights[0..<4] == heights[4...])
        for label in labels {
            #expect(label.alignmentRect(forFrame: label.frame).width <= AnswerCell.columnWidth)
        }
    }

    @Test func voiceOverReadsTheCardAsOneSentence() {
        let cell = AnswerCell()
        cell.show(
            .init(
                id: "calculator", title: "54 × 1.15", subtitle: "Expression", kind: "Calculator",
                symbol: "", action: "Copy Answer", answer: .init(value: "62.1", detail: "Result")))
        #expect(cell.accessibilityLabel() == "54 × 1.15 equals 62.1")
        #expect(cell.accessibilityChildren()?.isEmpty == true)
    }
}
