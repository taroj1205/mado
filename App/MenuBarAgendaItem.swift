import AppCore
import AppKit
import os

@MainActor
final class MenuBarAgendaItem: NSObject, NSPopoverDelegate {
    struct Shown {
        let bar: MenuBarAgenda
        let found: [CalendarAgenda.Found]
        let now: Date
    }

    private static let interval: TimeInterval = 15
    private static let iconSize: CGFloat = 13
    private let logger = Log.logger("MenuBarAgenda")
    private weak var modules: ModuleManager?
    private var item: NSStatusItem?
    private var popover: NSPopover?
    private var panel: MenuBarAgendaPanel?
    private var fetching: Task<Void, Never>?
    private let upNext = UpNextFeed()
    private(set) var shown: Shown?
    var openSettings: (@MainActor () -> Void)?

    var settings: MenuBarAgendaSettings {
        get { .load(from: modules) }
        set {
            newValue.save(to: modules)
            refresh()
        }
    }

    func start(context: ModuleContext, modules: ModuleManager) {
        self.modules = modules
        context.scheduleTimer("menu bar agenda", interval: Self.interval) { [weak self] in
            self?.refresh()
        }
        upNext.refreshOnChange(in: context) { [weak self] in self?.refresh() }
        refresh()
    }

    func stop() {
        fetching?.cancel()
        fetching = nil
        modules = nil
        hide()
    }

    func popoverDidClose(_: Notification) {
        popover = nil
        panel = nil
    }

    func refresh() {
        fetching?.cancel()
        guard modules != nil, settings.isShown, CalendarAgenda.hasAccess else {
            hide()
            return
        }
        fetching = Task { [weak self] in
            let found = await self?.upNext.found(around: .now) ?? []
            guard !Task.isCancelled else { return }
            self?.show(found, at: .now)
        }
    }

    func run(_ action: CommandAction) {
        action.run(logging: logger)
    }

    private func show(_ found: [CalendarAgenda.Found], at now: Date) {
        let agenda = Agenda(events: found.map(\.event))
        guard let bar = MenuBarAgenda(agenda, at: now, calendar: .current) else {
            hide()
            return
        }
        let current = Shown(bar: bar, found: found, now: now)
        shown = current
        let button = (item ?? makeItem()).button
        let title = bar.title(showingEvent: !settings.hidesTitles)
        button?.title = title
        button?.image = icon(joining: bar.joins)
        button?.setAccessibilityLabel(title)
        panel?.update(current, hidesTitles: settings.hidesTitles)
    }

    private func hide() {
        shown = nil
        popover?.close()
        if let item { NSStatusBar.system.removeStatusItem(item) }
        item = nil
    }

    private func makeItem() -> NSStatusItem {
        let made = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        made.autosaveName = "agenda"
        made.button?.imagePosition = .imageLeading
        made.button?.target = self
        made.button?.action = #selector(clicked)
        made.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        StatusItemHover.install(on: made.button)
        item = made
        return made
    }

    private func icon(joining: Bool) -> NSImage? {
        let image = NSImage(
            systemSymbolName: joining ? "video.fill" : "calendar", accessibilityDescription: nil)
        return image?.withSymbolConfiguration(.init(pointSize: Self.iconSize, weight: .regular))
    }

    @objc
    private func clicked() {
        if let popover, popover.isShown {
            popover.close()
            return
        }
        guard let shown, let button = item?.button else { return }
        let event = NSApp.currentEvent
        let isPlainClick =
            event?.type == .leftMouseUp && event?.modifierFlags.contains(.control) == false
        if shown.bar.joins, isPlainClick, let meeting = shown.bar.event.meeting {
            run(CalendarAgenda.join(meeting))
            return
        }
        let content = makePanel()
        content.update(shown, hidesTitles: settings.hidesTitles)
        panel = content
        popover = MenuBarPanelStyle.present(content, below: button, delegate: self)
    }

    private func makePanel() -> MenuBarAgendaPanel {
        MenuBarAgendaPanel(
            .init(
                join: { [weak self] meeting in self?.act(CalendarAgenda.join(meeting)) },
                open: { [weak self] found in self?.act(CalendarAgenda.open(found)) },
                openCalendar: { [weak self] in
                    self?.act(Widgets.openApp(Widgets.calendarApp, titled: "Open Calendar"))
                },
                toggleTitles: { [weak self] in
                    self?.popover?.close()
                    self?.settings.hidesTitles.toggle()
                },
                openSettings: { [weak self] in
                    self?.popover?.close()
                    self?.openSettings?()
                }))
    }

    private func act(_ action: CommandAction) {
        popover?.close()
        run(action)
    }
}
