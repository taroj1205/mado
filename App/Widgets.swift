import AppCore
import AppKit
import GlassUI
import os
import SearchKit

@MainActor
final class Widgets {
    static let moduleID = "widgets"
    private static let clockApp = "com.apple.clock"
    static let minute: TimeInterval = 60
    private static let time = Date.FormatStyle().hour(.defaultDigits(amPM: .omitted)).minute()
    private static let spokenTime = Date.FormatStyle().hour().minute()
    private static let day = Date.FormatStyle().weekday(.abbreviated).day().month(.abbreviated)
    private static let spokenDay = Date.FormatStyle().weekday(.wide).day().month(.wide)
    private static let clockWidget = "clock"
    static let system = "system"
    static let music = "music"
    static let lyrics = "lyrics"
    static let weather = "weather"
    static let listenSeconds = 2.0
    static let followSeconds = 0.25
    static let player = MusicPlayer()
    static let logger = Log.logger("Widgets")
    static let battery = "battery"
    static let gallery: [WidgetGallery.Card] = [
        .init(
            id: calendarWidget, name: "Calendar", summary: "Month and today", group: .today,
            isWide: true, isTall: true),
        .init(
            id: upNext, name: "Up Next", summary: "Next event, ↵ joins", group: .today,
            isWide: true),
        .init(id: weather, name: "Weather", summary: "Now, high and low", group: .today),
        .init(id: clockWidget, name: "Clock", summary: "Time and date", group: .today),
        .init(
            id: music, name: "Now Playing", summary: "Music controls", group: .media,
            isWide: true),
        .init(
            id: lyrics, name: "Lyrics", summary: "Synced lyrics, click to jump", group: .media,
            isWide: true, isTall: true),
        .init(id: battery, name: "Battery", summary: "Mac and devices", group: .system),
        .init(id: system, name: "System", summary: "CPU and memory", group: .system),
    ]

    static var ids: [String] {
        gallery.map(\.id)
    }

    static var wide: Set<String> {
        Set(gallery.filter(\.isWide).map(\.id))
    }

    static var tall: Set<String> {
        Set(gallery.filter(\.isTall).map(\.id))
    }

    private static var clock: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: clockApp)
    }

    var shown: [String] = []
    var city = ""
    let weatherFeed = WeatherFeed()
    var calendars = Calendars()
    private(set) var stats: SystemStats?
    var searched: [WidgetQuery.Kind] = []
    var delivered: [ResultList.Item] = []
    var onSearchedChange: (() -> Void)?
    var playing: MusicPlayer.Track?
    private var ticking: Task<Void, Never>?
    var listening: Task<Void, Never>?
    var following: Task<Void, Never>?
    var lyricsEnabled = false
    let lyricsFeed = LyricsFeed()

    static func added(in modules: ModuleManager?) -> [String] {
        WidgetSettings.load(from: modules).added(from: ids)
    }

    static func edit(_ edit: WidgetSettings.Edit, in modules: ModuleManager?) {
        var settings = WidgetSettings.load(from: modules)
        let spot: WidgetGrid.Spot? =
            switch edit {
            case .add: .panel
            case let .place(_, spot, _), let .group(_, spot, _): spot
            case .spread(let spots): spots.values.first
            case .move, .resize, .remove: nil
            }
        if let spot, spot != .panel || WidgetPlacement.load(from: modules) != .inPanel {
            do {
                try WidgetPlacement.pin(&settings, of: ids, in: modules)
            } catch {
                logger.error("Placement failed to save: \(error, privacy: .public)")
            }
        }
        settings.apply(edit, from: ids)
        settings.save(to: modules)
    }

    static func name(of id: String) -> String {
        gallery.first { $0.id == id }?.name ?? id
    }

    private static func current(
        at date: Date, stats: SystemStats?, media: [WidgetGrid.Widget],
        weather: WeatherFeed.State, schedule: Schedule
    ) -> [WidgetGrid.Widget] {
        let cpu = stats?.cpu
        let memory = stats?.memory
        return [
            widget(for: schedule, at: date),
            widget(for: weather),
            .init(
                id: clockWidget, name: name(of: clockWidget), value: date.formatted(time),
                detail: date.formatted(day),
                action: clock == nil ? "Open Date & Time Settings" : "Open Clock",
                spoken: "Time: \(date.formatted(spokenTime)), \(date.formatted(spokenDay))",
                facts: clockFacts(at: date)),
            stats == nil
                ? .init(
                    id: battery, name: name(of: battery), content: .loading(title: "Battery"),
                    action: batteryAction, spoken: "Battery: loading")
                : stats.flatMap(batteries),
            cpu == nil
                ? .init(
                    id: system, name: name(of: system), content: .loading(title: "System"),
                    action: "Open Activity Monitor", spoken: "System: loading")
                : .init(
                    id: system, name: name(of: system),
                    meters: [meter("CPU", cpu), meter("RAM", memory)],
                    action: "Open Activity Monitor",
                    spoken: "System: CPU \(percent(cpu)), memory \(percent(memory))",
                    facts: systemFacts(of: stats)),
        ]
        .compactMap(\.self) + media
    }

    static func meter(_ name: String, _ level: Double?) -> WidgetGrid.Meter {
        .init(name: name, value: percent(level), level: level ?? 0)
    }

    static func percent(_ level: Double?) -> String {
        level?.formatted(StatusPills.percent) ?? StatusPills.unknown
    }

    private static func unavailable(_ id: String) -> WidgetGrid.Widget? {
        gallery.first { $0.id == id }?.placeholder
    }

    func action(for widget: WidgetGrid.Widget) -> CommandAction {
        action(forWidget: widget.id, titled: widget.action)
    }

    func action(forWidget id: String, titled title: String) -> CommandAction {
        switch id {
        case Self.system: return StatusPills.open(StatusPills.activityMonitor, title: title)
        case Self.battery: return SettingsPane.battery.open
        case Self.weather: return weatherAction(titled: title)
        case Self.calendarWidget: return Self.openApp(Self.calendarApp, titled: title)
        case Self.upNext: return upNextAction(titled: title)
        default: break
        }
        guard let clock = Self.clock else { return SettingsPane.dateAndTime.open }
        return CommandAction(id: "open", title: title) {
            _ = try await NSWorkspace.shared.openApplication(
                at: clock, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    func show(in view: LauncherView) {
        stop()
        weatherFeed.onChange = { [weak self, weak view] in
            guard let self, let view else { return }
            refresh(view)
        }
        refreshWeather()
        refreshCalendars(in: view)
        refresh(view)
        ticking = Task { [weak self, weak view] in
            while !Task.isCancelled {
                let now = Date.now.timeIntervalSinceReferenceDate
                let wait = Self.minute - now.truncatingRemainder(dividingBy: Self.minute)
                try? await Task.sleep(for: .seconds(wait))
                guard !Task.isCancelled, let self, let view else { return }
                refreshWeather()
                refreshCalendars(in: view)
                refresh(view)
            }
        }
        listen(in: view)
    }

    func show(_ ids: [String], in view: LauncherView) {
        shown = ids
        refreshWeather()
        refreshCalendars(in: view)
        refresh(view)
    }

    func show(_ stats: SystemStats, in view: LauncherView) {
        self.stats = stats
        refresh(view)
    }

    func control(_ control: MusicPlayer.Control, in view: LauncherView) {
        Task { [weak self, weak view] in
            do {
                let found = try await Self.player.perform(control)
                guard let self, let view else { return }
                playing = found
                refresh(view)
            } catch {
                Self.logger.error("Music control failed: \(error, privacy: .private)")
            }
        }
    }

    func openPlayer() {
        Task {
            guard let bundleID = playing?.bundleID else { return }
            do {
                try await Self.openApp(bundleID, titled: "Open").perform()
            } catch {
                Self.logger.error("Opening the player failed: \(error, privacy: .private)")
            }
        }
    }

    func stop() {
        ticking?.cancel()
        ticking = nil
        listening?.cancel()
        listening = nil
        following?.cancel()
        following = nil
        calendars.stop()
        weatherFeed.cancel()
        searched = []
        delivered = []
    }

    func current() -> [WidgetGrid.Widget] {
        [
            Self.month(
                at: .now, shift: calendars.monthShift, events: calendars.monthEvents,
                calendars: calendars)
        ]
            + Self.current(
                at: .now, stats: stats, media: mediaWidgets(), weather: weatherFeed.state,
                schedule: calendars.schedule)
    }

    func refresh(_ view: LauncherView) {
        let all = current()
        view.widgets = shown.compactMap { id in all.first { $0.id == id } ?? Self.unavailable(id) }
        view.widgetPreviews = all
        refreshCards(among: all)
    }
}
