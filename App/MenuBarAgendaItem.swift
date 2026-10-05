import AppCore
import AppKit
import os

@MainActor
final class MenuBarAgendaItem: NSObject {
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
    private var fetching: Task<Void, Never>?
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
        refresh()
    }

    func stop() {
        fetching?.cancel()
        fetching = nil
        modules = nil
        hide()
    }

    func refresh() {
        fetching?.cancel()
        guard modules != nil, settings.isShown, CalendarAgenda.hasAccess else {
            hide()
            return
        }
        fetching = Task { [weak self] in
            let found = await CalendarAgenda.upNext(around: .now)
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
        shown = Shown(bar: bar, found: found, now: now)
        let button = (item ?? makeItem()).button
        let title = bar.title(showingEvent: !settings.hidesTitles)
        button?.title = title
        button?.image = icon(joining: bar.joins)
        button?.setAccessibilityLabel(title)
    }

    private func hide() {
        shown = nil
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
        guard let shown, let item else { return }
        let event = NSApp.currentEvent
        let isPlainClick =
            event?.type == .leftMouseUp && event?.modifierFlags.contains(.control) == false
        if shown.bar.joins, isPlainClick, let meeting = shown.bar.event.meeting {
            run(CalendarAgenda.join(meeting))
            return
        }
        item.menu = makeMenu(for: shown)
        item.button?.performClick(nil)
        item.menu = nil
    }
}
