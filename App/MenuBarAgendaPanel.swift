import AppCore
import AppKit

final class MenuBarAgendaPanel: NSView, MenuBarPanel {
    private typealias Style = MenuBarPanelStyle

    struct Handlers {
        let join: (Meeting) -> Void
        let open: (CalendarAgenda.Found) -> Void
        let openCalendar: () -> Void
        let toggleTitles: () -> Void
        let openSettings: () -> Void
    }

    private struct Action {
        let symbol: String
        let text: String
        let press: () -> Void
    }

    private static let buttonSpacing: CGFloat = 6
    private static let joinKey = "j"

    var onResize: ((NSSize) -> Void)?
    private let handlers: Handlers
    private let stack = NSStackView()
    private var joinNext: (() -> Void)?

    init(_ handlers: Handlers) {
        self.handlers = handlers
        super.init(frame: .zero)
        Style.install(stack, in: self)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func today(in shown: MenuBarAgendaItem.Shown) -> [CalendarAgenda.Found] {
        let calendar = Calendar.current
        let heading = Agenda.heading(for: shown.now, at: shown.now, calendar: calendar)
        let events = Agenda(events: shown.found.map(\.event))
            .days(under: [heading], calendar: calendar).flatMap(\.events)
        return events.compactMap { event in shown.found.first { $0.event.id == event.id } }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let isJoin =
            event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command
            && event.charactersIgnoringModifiers == Self.joinKey
        guard isJoin, let joinNext else { return super.performKeyEquivalent(with: event) }
        joinNext()
        return true
    }

    func update(_ shown: MenuBarAgendaItem.Shown, hidesTitles: Bool) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let event = shown.bar.event
        let meeting = event.meeting
        joinNext = meeting.map { meeting in { [handlers] in handlers.join(meeting) } }
        addHero(of: event, at: shown.now)
        if let meeting {
            let join = MenuBarPanelButton(
                "Join  \(CalendarAgenda.joinKeys.joined())", isPrimary: true
            ) { [handlers] in handlers.join(meeting) }
            let buttons = NSStackView(views: [join])
            buttons.spacing = Self.buttonSpacing
            stack.addArrangedSubview(buttons)
        }
        let today = Self.today(in: shown)
        if !today.isEmpty {
            Style.addRule(to: stack)
            let header = Style.label(Style.captionSize, weight: .semibold, secondary: true)
            header.stringValue = "TODAY"
            stack.addArrangedSubview(header)
            for found in today { addRow(found, at: shown.now) }
        }
        Style.addRule(to: stack)
        addActions(hidesTitles: hidesTitles)
        layoutSubtreeIfNeeded()
        setFrameSize(fittingSize)
        onResize?(frame.size)
    }

    private func addHero(of event: Agenda.Event, at now: Date) {
        let caption = Style.label(Style.captionSize, weight: .semibold, secondary: true)
        caption.stringValue = "NEXT · \(Agenda.countdown(to: event.start, at: now))".uppercased()
        let title = Style.label(Style.titleSize, weight: .semibold, secondary: false)
        title.stringValue = event.title
        let detail = Style.label(Style.detailSize, weight: .regular, secondary: true)
        detail.stringValue = [event.hours, event.place].filter { !$0.isEmpty }
            .joined(separator: " · ")
        let views = detail.stringValue.isEmpty ? [caption, title] : [caption, title, detail]
        Style.addFullWidth(Style.info(views), to: stack)
    }

    private func addRow(_ found: CalendarAgenda.Found, at now: Date) {
        let event = found.event
        let time = Agenda.time(
            of: event, listedFrom: Calendar.current.startOfDay(for: now), calendar: .current)
        let row = MenuBarPanelRow(
            symbol: event.meeting == nil ? "calendar" : "video", text: event.title,
            trailing: time, isHint: false, isDimmed: event.hasEnded(at: now)
        ) { [handlers] in handlers.open(found) }
        Style.addFullWidth(row, to: stack)
    }

    private func addActions(hidesTitles: Bool) {
        let actions = [
            Action(
                symbol: "arrow.up.forward.app", text: "Open Calendar",
                press: handlers.openCalendar),
            Action(
                symbol: hidesTitles ? "eye" : "eye.slash",
                text: "\(hidesTitles ? "Show" : "Hide") event titles in menu bar",
                press: handlers.toggleTitles),
            Action(symbol: "gearshape", text: "Calendar Settings…", press: handlers.openSettings),
        ]
        for action in actions {
            let row = MenuBarPanelRow(
                symbol: action.symbol, text: action.text, trailing: "", isHint: false,
                isDimmed: false, onPress: action.press)
            Style.addFullWidth(row, to: stack)
        }
    }
}
