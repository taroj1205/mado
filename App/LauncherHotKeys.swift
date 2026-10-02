import AppCore
import AppKit
import Carbon.HIToolbox
import GlassUI
import InputKit
import os

@MainActor
final class LauncherHotKeys {
    enum Key: String, LauncherSetting {
        case commandSpace = "command_space"
        case optionSpace = "option_space"

        static let allCases: [Self] = [.commandSpace, .optionSpace]
        static let field = "hotkey"
        static let fallback = Self.commandSpace

        var title: String {
            switch self {
            case .commandSpace: "⌘Space"
            case .optionSpace: "⌥Space"
            }
        }

        var shortcut: Shortcut {
            Shortcut(
                keyCode: UInt32(kVK_Space), modifiers: self == .commandSpace ? .command : .option)
        }
    }

    private static let confirmedField = "command_space_confirmed"
    private static let guideShownField = "spotlight_guide_shown"
    private static let guideWidth: CGFloat = 800
    private static let guideHeight: CGFloat = 660
    private static let guideRadius: CGFloat = 26

    var onChange: (() -> Void)?

    private let logger = Log.logger("App")
    private let modules: ModuleManager?
    private let registry: HotKeyRegistry?
    private let pressed: () -> Void
    private var registrations: [Key: HotKeyRegistration] = [:]
    private var observation: NSKeyValueObservation?
    private var guide: (window: NSWindow, view: SpotlightGuideView)?

    var key: Key {
        Key.load(from: modules)
    }

    private var spotlightHasCommandSpace: Bool {
        SystemShortcutConflicts.conflict(for: Key.commandSpace.shortcut) == .spotlight
    }

    private var commandSpaceReaches: Bool {
        LauncherSettings.value(Self.confirmedField, in: modules) == .bool(true)
    }

    init(modules: ModuleManager?, registry: HotKeyRegistry?, pressed: @escaping () -> Void) {
        self.modules = modules
        self.registry = registry
        self.pressed = pressed
    }

    static func makeRegistry() -> HotKeyRegistry? {
        #if DEBUG
            if UserDefaults.standard.bool(forKey: "MadoNoHotKey") { return nil }
        #endif
        do {
            return try HotKeyRegistry()
        } catch {
            Log.logger("App").error(
                "Launcher hotkey failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    func start() {
        observation = SystemShortcutConflicts.observe { [weak self] in self?.update() }
        update()
        let shown = LauncherSettings.value(Self.guideShownField, in: modules) == .bool(true)
        if registry != nil, key == .commandSpace, spotlightHasCommandSpace, !shown {
            save(true, for: Self.guideShownField)
            showGuide()
        }
    }

    func use(_ key: Key) throws {
        try key.save(to: modules)
        update()
        if key == .commandSpace, !commandSpaceReaches {
            showGuide()
        }
    }

    private func update() {
        if spotlightHasCommandSpace, commandSpaceReaches {
            save(false, for: Self.confirmedField)
        }
        let wanted: Set<Key> =
            if key == .optionSpace {
                [.optionSpace]
            } else if commandSpaceReaches {
                [.commandSpace]
            } else {
                [.commandSpace, .optionSpace]
            }
        for (held, registration) in registrations where !wanted.contains(held) {
            registry?.unregister(registration)
            registrations[held] = nil
        }
        for missing in wanted where registrations[missing] == nil {
            register(missing)
        }
        guide?.view.show(
            spotlightHasCommandSpace: spotlightHasCommandSpace,
            commandSpaceReaches: commandSpaceReaches)
        onChange?()
    }

    private func register(_ key: Key) {
        guard let registry else { return }
        do {
            registrations[key] = try registry.register(key.shortcut) { [weak self] in
                self?.fire(key)
            }
        } catch {
            let reason = String(describing: error)
            logger.error(
                "Launcher hotkey \(key.title, privacy: .public) failed: \(reason, privacy: .public)"
            )
        }
    }

    private func fire(_ key: Key) {
        if key == .commandSpace, !commandSpaceReaches, !spotlightHasCommandSpace {
            save(true, for: Self.confirmedField)
            update()
        }
        if guide?.window.isKeyWindow != true {
            pressed()
        }
    }

    private func save(_ value: Bool, for field: String) {
        do {
            try LauncherSettings.setValue(.bool(value), for: field, in: modules)
        } catch {
            logger.error("Saving \(field, privacy: .public) failed: \(error, privacy: .public)")
        }
    }

    private func showGuide() {
        let shown = guide ?? makeGuide()
        guide = shown
        update()
        NSApp.activate()
        shown.window.makeKeyAndOrderFront(nil)
        shown.window.makeFirstResponder(nil)
    }

    private func makeGuide() -> (window: NSWindow, view: SpotlightGuideView) {
        let view = SpotlightGuideView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Self.guideWidth, height: Self.guideHeight),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: true)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbar = NSToolbar()
        window.toolbarStyle = .unified
        window.title = "Use ⌘Space for Mado"
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        let glass = GlassView(shape: .rounded(Self.guideRadius))
        glass.contentView = view
        window.contentView = glass
        window.center()
        view.onClose = { [weak window] in window?.close() }
        view.onUseOptionSpace = { [weak self, weak window] in
            do {
                try self?.use(.optionSpace)
                window?.close()
            } catch {
                window?.presentError(error)
            }
        }
        return (window, view)
    }
}
