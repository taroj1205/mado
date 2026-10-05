import AppCore
import AppKit

extension MenuBarAgendaItem {
    private static let rowTitleLimit = 32
    private static let timeColumn: CGFloat = 66
    private static let iconColumn: CGFloat = 276
    private static let iconSize: CGFloat = 12
    private static let timeSize: CGFloat = 12

    func makeMenu(for shown: Shown) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let event = shown.bar.event
        let join = { [weak self] in
            if let meeting = event.meeting { self?.run(CalendarAgenda.join(meeting)) }
        }
        let card = NSMenuItem()
        card.view = MenuBarAgendaCard(
            event: event, now: shown.now, joinKeys: CalendarAgenda.joinKeys.joined(),
            onJoin: join)
        menu.addItem(card)
        if event.meeting != nil {
            let joinItem = menu.addItem(withTitle: "Join Meeting", action: nil, keyEquivalent: "j")
            joinItem.keyEquivalentModifierMask = .command
            joinItem.isHidden = true
            joinItem.allowsKeyEquivalentWhenHidden = true
            joinItem.target = self
            joinItem.action = #selector(joinNext)
        }
        menu.addItem(.sectionHeader(title: "Today"))
        for found in today(in: shown) {
            menu.addItem(row(for: found, at: shown.now))
        }
        menu.addItem(.separator())
        addActions(to: menu)
        return menu
    }

    private func today(in shown: Shown) -> [CalendarAgenda.Found] {
        let calendar = Calendar.current
        let heading = Agenda.heading(for: shown.now, at: shown.now, calendar: calendar)
        let events = Agenda(events: shown.found.map(\.event))
            .days(under: [heading], calendar: calendar).flatMap(\.events)
        return events.compactMap { event in shown.found.first { $0.event.id == event.id } }
    }

    private func row(for found: CalendarAgenda.Found, at now: Date) -> NSMenuItem {
        let event = found.event
        let item = NSMenuItem(title: event.title, action: #selector(openEvent), keyEquivalent: "")
        item.target = self
        item.representedObject = found
        let style = NSMutableParagraphStyle()
        style.tabStops = [
            NSTextTab(textAlignment: .left, location: Self.timeColumn),
            NSTextTab(textAlignment: .right, location: Self.iconColumn),
        ]
        let time = Agenda.time(
            of: event, listedFrom: Calendar.current.startOfDay(for: now), calendar: .current)
        let primary: NSColor = event.hasEnded(at: now) ? .tertiaryLabelColor : .labelColor
        let text = NSMutableAttributedString(
            string: "\(time)\t",
            attributes: [
                .foregroundColor: NSColor.secondaryLabelColor, .paragraphStyle: style,
                .font: NSFont.monospacedDigitSystemFont(ofSize: Self.timeSize, weight: .regular),
            ])
        text.append(
            NSAttributedString(
                string: MenuBarAgenda.shortened(event.title, to: Self.rowTitleLimit),
                attributes: [
                    .foregroundColor: primary, .paragraphStyle: style,
                    .font: NSFont.menuFont(ofSize: 0),
                ]))
        if event.meeting != nil {
            text.append(NSAttributedString(string: "\t", attributes: [.paragraphStyle: style]))
            text.append(NSAttributedString(attachment: videoIcon()))
        }
        item.attributedTitle = text
        return item
    }

    private func videoIcon() -> NSTextAttachment {
        let attachment = NSTextAttachment()
        attachment.image = NSImage(systemSymbolName: "video", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: Self.iconSize, weight: .regular))
        return attachment
    }

    private func addActions(to menu: NSMenu) {
        let open = menu.addItem(
            withTitle: "Open Calendar", action: #selector(openCalendar), keyEquivalent: "")
        let titles = settings.hidesTitles ? "Show" : "Hide"
        let toggle = menu.addItem(
            withTitle: "\(titles) event titles in menu bar", action: #selector(toggleTitles),
            keyEquivalent: "")
        let preferences = menu.addItem(
            withTitle: "Calendar Settings…", action: #selector(showSettings), keyEquivalent: "")
        for item in [open, toggle, preferences] { item.target = self }
    }

    @objc
    private func joinNext() {
        if let meeting = shown?.bar.event.meeting { run(CalendarAgenda.join(meeting)) }
    }

    @objc
    private func openEvent(_ sender: NSMenuItem) {
        if let found = sender.representedObject as? CalendarAgenda.Found {
            run(CalendarAgenda.open(found))
        }
    }

    @objc
    private func openCalendar() {
        run(Widgets.openApp(Widgets.calendarApp, titled: "Open Calendar"))
    }

    @objc
    private func toggleTitles() {
        settings.hidesTitles.toggle()
    }

    @objc
    private func showSettings() {
        openSettings?()
    }
}
