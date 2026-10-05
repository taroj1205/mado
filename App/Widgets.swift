import AppCore
import AppKit
import GlassUI
import os

@MainActor
final class Widgets {
    static let moduleID = "widgets"
    private static let clockApp = "com.apple.clock"
    private static let minute: TimeInterval = 60
    private static let time = Date.FormatStyle().hour(.defaultDigits(amPM: .omitted)).minute()
    private static let spokenTime = Date.FormatStyle().hour().minute()
    private static let day = Date.FormatStyle().weekday(.abbreviated).day().month(.abbreviated)
    private static let spokenDay = Date.FormatStyle().weekday(.wide).day().month(.wide)
    private static let clockWidget = "clock"
    private static let system = "system"
    static let music = "music"
    static let weather = "weather"
    private static let listenSeconds = 2.0
    private static let player = MusicPlayer()
    private static let logger = Log.logger("Widgets")
    private static let battery = "battery"
    private static let batteryAction = "Battery Settings"
    private static let macName = "Mac"
    private static let owner = #/^\S+['’]s /#
    private static let timeLeft = Duration.TimeFormatStyle(pattern: .hourMinute)
    private static let iconGrey: CGFloat = 0.227
    private static let iconBlue: CGFloat = 0.235
    private static let icon = NSColor(srgbRed: iconGrey, green: iconGrey, blue: iconBlue, alpha: 1)

    private static let musicRed: CGFloat = 0.851
    private static let musicGreen: CGFloat = 0.188
    private static let musicBlue: CGFloat = 0.290
    private static let musicIcon = NSColor(
        srgbRed: musicRed, green: musicGreen, blue: musicBlue, alpha: 1)
    private static let batteryRed: CGFloat = 0.188
    private static let batteryGreen: CGFloat = 0.694
    private static let batteryBlue: CGFloat = 0.345
    private static let batteryIcon = NSColor(
        srgbRed: batteryRed, green: batteryGreen, blue: batteryBlue, alpha: 1)
    private static let weatherRed: CGFloat = 0.114
    private static let weatherGreen: CGFloat = 0.435
    private static let weatherBlue: CGFloat = 0.839
    private static let weatherIcon = NSColor(
        srgbRed: weatherRed, green: weatherGreen, blue: weatherBlue, alpha: 1)

    static let gallery: [WidgetGallery.Card] = [
        .init(
            id: weather, name: "Weather", summary: "Now, high and low", size: .small,
            group: nil, symbol: "sun.max.fill", colour: weatherIcon),
        .init(
            id: clockWidget, name: "Clock", summary: "Time and date", size: .small,
            group: .time, symbol: "clock.fill", colour: icon),
        .init(
            id: music, name: "Now Playing", summary: "Music controls", size: .wide, group: nil,
            symbol: "heart.fill", colour: musicIcon),
        .init(
            id: battery, name: "Battery", summary: "Mac and devices", size: .small,
            group: .system, symbol: "battery.100percent", colour: batteryIcon),
        .init(
            id: system, name: "System", summary: "CPU and memory", size: .small,
            group: .system, symbol: "bolt.fill", colour: icon),
    ]

    static var ids: [String] {
        gallery.map(\.id)
    }

    private static var clock: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: clockApp)
    }

    var shown: [String] = []
    var city = ""
    let weatherFeed = WeatherFeed()
    private var stats: SystemStats?
    private var playing: MusicPlayer.Track?
    private var ticking: Task<Void, Never>?
    private var listening: Task<Void, Never>?

    static func added(in modules: ModuleManager?) -> [String] {
        WidgetSettings.load(from: modules).added(from: ids)
    }

    static func edit(_ edit: WidgetSettings.Edit, in modules: ModuleManager?) {
        var settings = WidgetSettings.load(from: modules)
        settings.apply(edit, from: ids)
        settings.save(to: modules)
    }

    static func name(of id: String) -> String {
        gallery.first { $0.id == id }?.name ?? id
    }

    private static func current(
        at date: Date, stats: SystemStats?, playing: MusicPlayer.Track?,
        weather: WeatherFeed.State
    ) -> [WidgetGrid.Widget] {
        let cpu = stats?.cpu
        let memory = stats?.memory
        return [
            widget(for: weather),
            .init(
                id: clockWidget, name: name(of: clockWidget), value: date.formatted(time),
                detail: date.formatted(day),
                action: clock == nil ? "Open Date & Time Settings" : "Open Clock",
                spoken: "Time: \(date.formatted(spokenTime)), \(date.formatted(spokenDay))"),
            playing.map(widget(for:)),
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
                    spoken: "System: CPU \(percent(cpu)), memory \(percent(memory))"),
        ]
        .compactMap(\.self)
    }

    private static func widget(for playing: MusicPlayer.Track) -> WidgetGrid.Widget {
        let song = playing.artist.isEmpty ? playing.title : "\(playing.title) by \(playing.artist)"
        return .init(
            id: music, name: name(of: music),
            track: .init(
                title: playing.title, artist: playing.artist, artwork: playing.artwork,
                isPlaying: playing.isPlaying),
            action: "Play / Pause",
            spoken: "\(playing.isPlaying ? "Now playing" : "Paused"): \(song)")
    }

    private static func batteries(in stats: SystemStats) -> WidgetGrid.Widget? {
        let mac = stats.battery
        let macStatus = mac.map { "\(percent($0.level)), \(status(of: $0).lowercased())" }
        guard let headphones = stats.headphones else {
            guard let mac, let macStatus else { return nil }
            return .init(
                id: battery, name: name(of: battery), value: percent(mac.level),
                detail: status(of: mac),
                action: batteryAction, spoken: "Battery: \(macStatus)",
                symbol: StatusPills.symbol(for: mac))
        }
        let spoken = [
            macStatus.map { "\(macName) \($0)" },
            "\(headphones.name) \(percent(headphones.level))",
        ]
        return .init(
            id: battery, name: name(of: battery),
            meters: [
                mac.map { meter(macName, $0.level) },
                meter(headphones.name.replacing(owner, with: ""), headphones.level),
            ]
            .compactMap(\.self),
            action: batteryAction,
            spoken: "Battery: \(spoken.compactMap(\.self).joined(separator: "; "))")
    }

    private static func status(of battery: SystemStats.Battery) -> String {
        switch battery.power {
        case .charging: "Charging"
        case .charged: "Charged"
        case .notCharging: "Not charging"

        case .draining(let minutes?):
            "\(Duration.seconds(Double(minutes) * minute).formatted(timeLeft)) left"

        case .draining(nil): "On battery"
        }
    }

    private static func meter(_ name: String, _ level: Double?) -> WidgetGrid.Meter {
        .init(name: name, value: percent(level), level: level ?? 0)
    }

    private static func percent(_ level: Double?) -> String {
        level?.formatted(StatusPills.percent) ?? StatusPills.unknown
    }

    private static func unavailable(_ id: String) -> WidgetGrid.Widget? {
        gallery.first { $0.id == id }.map { card in
            .init(
                id: id, name: card.name,
                content: .unavailable(title: card.name, summary: card.summary), action: "",
                spoken: "\(card.name): \(card.summary)", isWide: card.size != .small)
        }
    }

    func action(for widget: WidgetGrid.Widget) -> CommandAction {
        switch widget.id {
        case Self.system: return StatusPills.open(StatusPills.activityMonitor, title: widget.action)
        case Self.battery: return SettingsPane.battery.open
        case Self.weather: return weatherAction(titled: widget.action)
        default: break
        }
        guard let clock = Self.clock else { return SettingsPane.dateAndTime.open }
        return CommandAction(id: "open", title: widget.action) {
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
        refresh(view)
        ticking = Task { [weak self, weak view] in
            while !Task.isCancelled {
                let now = Date.now.timeIntervalSinceReferenceDate
                let wait = Self.minute - now.truncatingRemainder(dividingBy: Self.minute)
                try? await Task.sleep(for: .seconds(wait))
                guard !Task.isCancelled, let self, let view else { return }
                refreshWeather()
                refresh(view)
            }
        }
        listening = Task { [weak self, weak view] in
            while !Task.isCancelled {
                let found = await Self.player.track()
                guard !Task.isCancelled, let self, let view else { return }
                playing = found
                refresh(view)
                try? await Task.sleep(for: .seconds(Self.listenSeconds))
            }
        }
    }

    func show(_ ids: [String], in view: LauncherView) {
        shown = ids
        refreshWeather()
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

    func stop() {
        ticking?.cancel()
        ticking = nil
        listening?.cancel()
        listening = nil
        weatherFeed.cancel()
    }

    private func refresh(_ view: LauncherView) {
        let all = Self.current(
            at: .now, stats: stats, playing: playing, weather: weatherFeed.state)
        view.widgets = shown.compactMap { id in all.first { $0.id == id } ?? Self.unavailable(id) }
    }
}
