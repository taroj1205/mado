import AppCore
import Foundation
import GlassUI
import SearchKit

extension Widgets {
    private static let cardPrefix = "widget."
    private static let noBattery = "No battery found"

    static func owns(_ id: String) -> Bool {
        id.hasPrefix(cardPrefix)
    }

    private static func id(of kind: WidgetQuery.Kind) -> String {
        switch kind {
        case .weather: weather
        case .battery: battery
        case .system: system
        case .calendar: calendarWidget
        }
    }

    private static func message(of widget: WidgetGrid.Widget?) -> ResultList.WidgetCard {
        let (headline, detail) =
            switch widget?.content {
            case let .permission(_, request, reason): (request, reason)
            case let .notice(_, headline, detail): (headline, detail)
            default: ("Loading…", "")
            }
        return .init(
            body: .message(headline: headline, detail: detail), spoken: widget?.spoken ?? "")
    }

    func sections(
        for query: String, enabled: Bool, in view: LauncherView
    ) -> [ResultList.Section] {
        let kinds = enabled ? WidgetQuery.kinds(for: query) : []
        if kinds != searched {
            searched = kinds
            delivered = []
            refreshWeather()
            refreshSchedule(in: view)
        }
        delivered = items(among: current())
        return delivered.map { ResultList.Section(title: $0.title, items: [$0]) }
    }

    func action(forCard item: ResultList.Item) -> CommandAction {
        let id = String(item.id.dropFirst(Self.cardPrefix.count))
        if id == Self.calendarWidget, case .blocked = schedule {
            return CalendarAgenda.allow(titled: item.action)
        }
        return action(forWidget: id, titled: item.action)
    }

    func refreshCards(among all: [WidgetGrid.Widget]) {
        let items = items(among: all)
        guard !delivered.isEmpty, items != delivered else { return }
        delivered = items
        onSearchedChange?()
    }

    private func items(among all: [WidgetGrid.Widget]) -> [ResultList.Item] {
        searched.map { kind in
            let id = Self.id(of: kind)
            let widget = all.first { $0.id == id }
            let (card, action) = card(for: kind, widget: widget)
            var item = ResultList.Item(
                id: Self.cardPrefix + id, title: Self.name(of: id), subtitle: "", kind: "",
                symbol: "", action: action)
            item.widget = card
            item.prefersSelection = true
            return item
        }
    }

    private func card(
        for kind: WidgetQuery.Kind, widget: WidgetGrid.Widget?
    ) -> (card: ResultList.WidgetCard, action: String) {
        let action = widget?.action ?? ""
        switch (kind, weatherFeed.state, widget?.content) {
        case let (.weather, .ready(now), _):
            return (Self.forecast(of: now, at: .now, spoken: widget?.spoken ?? ""), action)

        case (.system, _, .meters(let meters)):
            return (.init(body: .meters(meters), spoken: widget?.spoken ?? ""), action)

        case (.battery, _, _):
            return (batteryCard(spoken: widget?.spoken), widget?.action ?? Self.batteryAction)

        case (.calendar, _, _):
            return (Self.today(in: schedule, at: .now), "Open Calendar")

        default:
            return (Self.message(of: widget), action)
        }
    }

    private func batteryCard(spoken: String?) -> ResultList.WidgetCard {
        guard let stats else { return Self.message(of: nil) }
        let meters = Self.batteryMeters(in: stats)
        guard !meters.isEmpty else {
            return .init(
                body: .message(headline: Self.noBattery, detail: ""),
                spoken: "\(Self.name(of: Self.battery)): \(Self.noBattery)")
        }
        return .init(body: .meters(meters), spoken: spoken ?? "")
    }
}
