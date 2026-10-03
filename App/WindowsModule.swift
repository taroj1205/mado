import AppCore
import Carbon.HIToolbox
import GlassUI
import InputKit
import os
import WindowKit

struct WindowsModule: Module {
    static let id = "windows"
    static let switcherShortcuts = [
        Shortcut(keyCode: UInt32(kVK_Tab), modifiers: .option),
        Shortcut(keyCode: UInt32(kVK_Tab), modifiers: [.option, .shift]),
    ]
    let descriptor: ModuleDescriptor
    let hotKeys: HotKeyRegistry?
    let layoutSettings: @MainActor () -> LayoutSettings
    let radialSettings: @MainActor () -> RadialSettings
    let gestureSettings: @MainActor () -> GestureSettings
    let switcherSettings: @MainActor () -> SwitcherSettings
    let radialRing = OverlayPanel()
    let radialPreview = SnapPreview()

    func start(context: ModuleContext) {
        registerLayouts(context: context)
        context.startKeyFeatures {
            let radial = radialSettings()
            if radial.isEnabled {
                startRadialMenu(trigger: radial.trigger, context: context)
            }
            startGestures(gestureSettings(), context: context)
            startSwitcher(context: context)
        }
        context.logger.debug("Started")
    }

    func stop() {
        Log.logger(descriptor.id).debug("Stopped")
    }

    private func registerLayouts(context: ModuleContext) {
        do {
            for command in WindowLayouts.commands(settings: layoutSettings) {
                try context.register(command)
            }
        } catch {
            context.logger.error(
                "Layout commands failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func startRadialMenu(trigger: Shortcut.Modifiers, context: ModuleContext) {
        let radialMenu = RadialMenu(
            logger: context.logger, panel: radialRing, preview: radialPreview,
            settings: radialSettings
        ) { layoutSettings().gap }
        context.own(.other, "radial menu") { radialMenu.stop() }
        context.installWhenTrusted("radial trigger") {
            do {
                try ModifierTrigger.install(
                    trigger, name: "radial trigger", context: context,
                    onEvent: radialMenu.handle)
                return true
            } catch {
                return false
            }
        }
    }

    private func startGestures(_ settings: GestureSettings, context: ModuleContext) {
        let gesture = WindowGesture(logger: context.logger, settings: gestureSettings)
        context.own(.other, "window gesture") { gesture.stop() }
        let triggers: [(WindowDrag.Mode, Shortcut.Modifiers)] = [
            (.move, settings.move), (.resize, settings.resize),
        ]
        for (mode, held) in triggers {
            let name = "\(mode) gesture trigger"
            context.installWhenTrusted(name) {
                do {
                    try ModifierTrigger.install(held, name: name, context: context) { event in
                        gesture.handle(event, mode: mode, held: held)
                    }
                    return true
                } catch {
                    return false
                }
            }
        }
    }

    private func startSwitcher(context: ModuleContext) {
        guard let hotKeys else { return }
        let switcher = WindowSwitcher(logger: context.logger) { switcherSettings().order }
        context.own(.other, "window switcher") { switcher.stop() }
        do {
            for (shortcut, backward) in zip(Self.switcherShortcuts, [false, true]) {
                try hotKeys.register(
                    shortcut, name: "window switcher hotkey", context: context
                ) { switcher.step(backward: backward) }
            }
        } catch {
            context.logger.error(
                "Window switcher hotkey failed: \(String(describing: error), privacy: .public)")
            return
        }
        context.installWhenTrusted("window switcher keys") {
            do {
                try SwitcherKeys.install(
                    name: "window switcher keys", context: context,
                    isOpen: { switcher.isOpen }, onEvent: switcher.handle)
                return true
            } catch {
                return false
            }
        }
    }
}
