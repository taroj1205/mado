import AppCore
import Carbon.HIToolbox
import GlassUI
import InputKit
import os
import WindowKit

struct WindowsModule: Module {
    static let id = "windows"
    let descriptor: ModuleDescriptor
    let hotKeys: HotKeyRegistry?
    let radialSettings: @MainActor () -> RadialSettings
    let gestureSettings: @MainActor () -> GestureSettings
    let radialRing = OverlayPanel()
    let radialPreview = SnapPreview()

    func start(context: ModuleContext) {
        let radial = radialSettings()
        if radial.isEnabled {
            startRadialMenu(trigger: radial.trigger, context: context)
        }
        startGestures(gestureSettings(), context: context)
        startSwitcher(context: context)
        context.logger.debug("Started")
    }

    func stop() {
        Log.logger(descriptor.id).debug("Stopped")
    }

    private func startRadialMenu(trigger: Shortcut.Modifiers, context: ModuleContext) {
        let radialMenu = RadialMenu(
            logger: context.logger, panel: radialRing, preview: radialPreview,
            settings: radialSettings)
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
        let gesture = WindowGesture(logger: context.logger)
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
        let switcher = WindowSwitcher(logger: context.logger)
        context.own(.other, "window switcher") { switcher.stop() }
        do {
            for backward in [false, true] {
                let modifiers: Shortcut.Modifiers = backward ? [.option, .shift] : .option
                try hotKeys.register(
                    Shortcut(keyCode: UInt32(kVK_Tab), modifiers: modifiers),
                    name: "window switcher hotkey", context: context
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
