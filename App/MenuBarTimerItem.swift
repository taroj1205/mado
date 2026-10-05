import AppCore
import AppKit

@MainActor
final class MenuBarTimerItem: NSObject, NSPopoverDelegate {
    private static let tickMilliseconds = 500
    private static let iconSize: CGFloat = 13
    private static let chime = "Glass"

    private weak var modules: ModuleManager?
    private var item: NSStatusItem?
    private var popover: NSPopover?
    private var panel: MenuBarTimerPanel?
    private var ticking: Task<Void, Never>?
    private(set) var timers = Timers()
    var openLauncher: (@MainActor () -> Void)?

    var isOn: Bool {
        modules != nil
    }

    private static func playChime() {
        let name = chime
        Task.detached {
            guard let sound = NSSound(named: name) else { return }
            sound.play()
            try? await Task.sleep(for: .seconds(sound.duration))
        }
    }

    func start(modules: ModuleManager) {
        self.modules = modules
        timers = .load(from: modules)
        sync()
    }

    func stop() {
        ticking?.cancel()
        ticking = nil
        popover?.close()
        removeItem()
        modules = nil
    }

    func startTimer(_ length: TimeInterval, named name: String) {
        change { $0.add(length, named: name.isEmpty ? Timers.defaultName : name, at: $1) }
    }

    func startStopwatch() {
        change { $0.startStopwatch(at: $1) }
    }

    func startPomodoro(_ label: String) {
        change { $0.startPomodoro(label, at: $1) }
    }

    func popoverDidClose(_: Notification) {
        popover = nil
        panel = nil
    }

    private func change(_ edit: (inout Timers, Date) -> Void) {
        guard modules != nil else { return }
        edit(&timers, .now)
        timers.save(to: modules)
        sync()
    }

    private func sync() {
        let now = Date.now
        if !timers.tick(at: now).isEmpty {
            timers.save(to: modules)
            Self.playChime()
        }
        render(at: now)
        ensureTicking()
    }

    private func render(at now: Date) {
        guard modules != nil, let headline = timers.headline(at: now) else {
            popover?.close()
            removeItem()
            return
        }
        let button = (item ?? makeItem()).button
        button?.title = headline.text
        button?.image = icon(for: headline.state)
        button?.setAccessibilityLabel("Timer \(headline.text)")
        panel?.update(TimerPanel(timers, at: now, calendar: .current))
    }

    private func ensureTicking() {
        guard ticking == nil, timers.isTicking(at: .now) else { return }
        ticking = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(Self.tickMilliseconds))
                guard let self, !Task.isCancelled else { return }
                sync()
                if !timers.isTicking(at: .now) {
                    ticking = nil
                    return
                }
            }
        }
    }

    private func makeItem() -> NSStatusItem {
        let made = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        made.autosaveName = "timer"
        made.button?.imagePosition = .imageLeading
        made.button?.font = .monospacedDigitSystemFont(
            ofSize: NSFont.systemFontSize, weight: .regular)
        made.button?.target = self
        made.button?.action = #selector(clicked)
        item = made
        return made
    }

    private func removeItem() {
        if let item { NSStatusBar.system.removeStatusItem(item) }
        item = nil
    }

    private func icon(for state: Timers.State) -> NSImage? {
        let symbol =
            switch state {
            case .running: "timer"
            case .paused: "pause.circle"
            case .done: "bell.fill"
            }
        let size = NSImage.SymbolConfiguration(pointSize: Self.iconSize, weight: .regular)
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        guard state != .paused else { return image?.withSymbolConfiguration(size) }
        let colour = NSImage.SymbolConfiguration(paletteColors: [.systemOrange])
        return image?.withSymbolConfiguration(size.applying(colour))
    }

    @objc
    private func clicked() {
        if let popover, popover.isShown {
            popover.close()
            return
        }
        guard let button = item?.button else { return }
        let content = makePanel()
        let controller = NSViewController()
        controller.view = content
        content.onResize = { [weak controller] size in controller?.preferredContentSize = size }
        content.update(TimerPanel(timers, at: .now, calendar: .current))
        let shown = NSPopover()
        shown.behavior = .transient
        shown.delegate = self
        shown.contentViewController = controller
        panel = content
        popover = shown
        shown.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate()
    }

    private func makePanel() -> MenuBarTimerPanel {
        MenuBarTimerPanel(
            .init(
                act: { [weak self] action in self?.change { $0.perform(action, at: $1) } },
                show: { [weak self] mode in self?.change { timers, _ in timers.mode = mode } },
                select: { [weak self] id in self?.change { timers, _ in timers.select(id) } },
                newTimer: { [weak self] in
                    self?.popover?.close()
                    self?.openLauncher?()
                }))
    }
}
