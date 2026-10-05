import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct WidgetCellTests {
    private static let width: CGFloat = 744
    private let hours = (0..<6).map { index in
        ResultList.WidgetHour(
            label: index == 0 ? "Now" : "\(index + 10) AM", symbol: "cloud", value: "1\(index)°")
    }

    private func labels(in view: NSView) -> [NSTextField] {
        ((view as? NSTextField).map { [$0] } ?? []) + view.subviews.flatMap(labels)
    }

    private func texts(in view: NSView) -> [String] {
        labels(in: view).map(\.stringValue)
    }

    private func item(_ card: ResultList.WidgetCard) -> ResultList.Item {
        var item = ResultList.Item(
            id: "widget.weather", title: "Weather", subtitle: "", kind: "", symbol: "",
            action: "Open Weather")
        item.widget = card
        item.prefersSelection = true
        return item
    }

    private func list(showing card: ResultList.WidgetCard) -> ResultList {
        let app = ResultList.Item(
            id: "app", title: "Weather", subtitle: "", kind: "Application", symbol: "",
            action: "Open Application")
        let list = ResultList()
        list.reducesMotion = { true }
        list.frame = NSRect(x: 0, y: 0, width: Self.width, height: 415)
        list.sections = [
            .init(title: "Weather", items: [item(card)]), .init(title: "Results", items: [app]),
        ]
        list.layoutSubtreeIfNeeded()
        return list
    }

    private func forecast() -> ResultList.WidgetCard {
        .init(
            body: .forecast(
                symbol: "cloud.sun", value: "15°", detail: "Partly cloudy · H 17° L 11°",
                hours: hours),
            spoken: "Weather: 15°, partly cloudy")
    }

    @Test func aWidgetCardIsATallSelectedRowAboveTheResults() throws {
        let list = list(showing: forecast())
        #expect(list.table.rect(ofRow: 1).height == ResultList.answerHeight + ResultList.rowGap)
        #expect(list.table.rect(ofRow: 3).height == ResultList.rowHeight + ResultList.rowGap)
        #expect(list.selectedItem?.id == "widget.weather")
        let row = try #require(list.table.rowView(atRow: 1, makeIfNecessary: false))
        #expect((row as? ResultRowView)?.radius == AnswerCell.radius)
        #expect(list.table.view(atColumn: 0, row: 1, makeIfNecessary: false) is WidgetCell)
    }

    @Test func theForecastShowsTheTemperatureOnTheLeftAndEveryHourOnTheRight() throws {
        let list = list(showing: forecast())
        let cell = try #require(
            list.table.view(atColumn: 0, row: 1, makeIfNecessary: false) as? WidgetCell)
        cell.layoutSubtreeIfNeeded()
        let shown = texts(in: cell)
        for text in ["15°", "Partly cloudy · H 17° L 11°", "Now", "11 AM", "15 AM"] {
            #expect(shown.contains(text))
        }
        let labels = labels(in: cell)
        let temperature = try #require(labels.first { $0.stringValue == "15°" })
        let last = try #require(labels.first { $0.stringValue == "15 AM" })
        let left = cell.convert(temperature.bounds, from: temperature)
        let right = cell.convert(last.bounds, from: last)
        #expect(left.maxX < right.minX)
        #expect(right.maxX <= cell.bounds.width)
        #expect(cell.bounds.width - right.maxX < 40)
        #expect(abs(left.midY - cell.bounds.midY) < ResultList.answerHeight / 3)
    }

    @Test func aLongConditionTruncatesInsteadOfCoveringTheHours() throws {
        let long = ResultList.WidgetCard(
            body: .forecast(
                symbol: "cloud", value: "15°", detail: String(repeating: "Cloudy ", count: 30),
                hours: hours),
            spoken: "")
        let cell = WidgetCell(frame: NSRect(x: 0, y: 0, width: Self.width, height: 116))
        cell.show(long)
        cell.layoutSubtreeIfNeeded()
        let labels = labels(in: cell)
        let detail = try #require(labels.first { $0.stringValue.hasPrefix("Cloudy") })
        let now = try #require(labels.first { $0.stringValue == "Now" })
        let near = cell.convert(detail.bounds, from: detail)
        let far = cell.convert(now.bounds, from: now)
        #expect(near.maxX <= far.minX)
    }

    @Test func metersGrowTheCardOneBarAtATime() {
        let meter = { WidgetGrid.Meter(name: "CPU", value: "40%", level: 0.4) }
        let one = WidgetCell.height(for: .init(body: .meters([meter()]), spoken: ""))
        let two = WidgetCell.height(for: .init(body: .meters([meter(), meter()]), spoken: ""))
        #expect(one < two)
        #expect(two < ResultList.answerHeight)
        let three = WidgetCell.height(
            for: .init(body: .meters([meter(), meter(), meter()]), spoken: ""))
        #expect(three - two == two - one)
    }

    @Test func metersShowTheirNamesAndValues() throws {
        let card = ResultList.WidgetCard(
            body: .meters([
                .init(name: "CPU", value: "40%", level: 0.4),
                .init(name: "RAM", value: "71%", level: 0.71),
            ]),
            spoken: "System: CPU 40%, memory 71%")
        let list = list(showing: card)
        let cell = try #require(
            list.table.view(atColumn: 0, row: 1, makeIfNecessary: false) as? WidgetCell)
        cell.layoutSubtreeIfNeeded()
        #expect(texts(in: cell) == ["CPU", "40%", "RAM", "71%"])
        #expect(cell.frame.height == list.table.rect(ofRow: 1).height - ResultList.rowGap)
    }

    @Test func eventsListTheirTimeAndTitle() throws {
        let card = ResultList.WidgetCard(
            body: .events([
                .init(time: "9:30 AM", title: "Stand-up", colour: .systemBlue),
                .init(time: "All day", title: "Offsite", colour: .systemGreen),
            ]),
            spoken: "Calendar: 2 events")
        let list = list(showing: card)
        let cell = try #require(
            list.table.view(atColumn: 0, row: 1, makeIfNecessary: false) as? WidgetCell)
        #expect(texts(in: cell) == ["9:30 AM", "Stand-up", "All day", "Offsite"])
    }

    @Test func aMessageDropsAnEmptyDetail() {
        let cell = WidgetCell(frame: NSRect(x: 0, y: 0, width: Self.width, height: 76))
        cell.show(.init(body: .message(headline: "Allow location", detail: ""), spoken: ""))
        cell.layoutSubtreeIfNeeded()
        #expect(labels(in: cell).filter { !$0.isHidden }.map(\.stringValue) == ["Allow location"])
    }

    @Test func voiceOverReadsTheSpokenSummaryAsOneElement() {
        let cell = WidgetCell()
        cell.show(forecast())
        #expect(cell.accessibilityLabel() == "Weather: 15°, partly cloudy")
        #expect(cell.accessibilityChildren()?.isEmpty == true)
    }
}
