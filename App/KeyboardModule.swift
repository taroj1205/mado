import AppCore
import AppKit
import GlassUI
import InputKit
import os

struct KeyboardModule: Module {
    static let id = "keyboard"

    let descriptor: ModuleDescriptor
    let hotKeys: HotKeyRegistry?
    let inputSourceSettings: @MainActor () -> InputSourceSettings
    let remapSettings: @MainActor () -> RemapSettings
    let showLauncher: @MainActor (_ toggles: Bool) -> Void
    let inputMemory = AppInputSwitch.Memory()

    func start(context: ModuleContext) {
        AppInputSwitch.trackActivationsWhileStopped(context: context, memory: inputMemory)
        context.startKeyFeatures {
            let remaps = remapSettings()
            let claimed = remaps.claimsRightControlTap ? HotKey.modifierTap(.rightControl) : nil
            installInputKeys(
                inputSourceSettings().keys.filter { $0.hotKey != claimed }, context: context)
            AppInputSwitch.install(
                context: context, settings: inputSourceSettings, memory: inputMemory)
            startRemaps(remaps, context: context)
        }
    }

    func stop() {
        Log.logger(descriptor.id).debug("Stopped")
    }

    private func installInputKeys(_ keys: [InputKey], context: ModuleContext) {
        var taps: [ModifierTap.Tap: @MainActor () -> Void] = [:]
        for key in keys {
            let select = { @MainActor in
                guard !(NSApp.keyWindow?.firstResponder is HotKeyRecorder) else { return }
                key.target.select()
            }
            switch key.hotKey {
            case .modifierTap(let modifier):
                taps[ModifierTap.Tap(modifier)] = select

            case .shortcut(let shortcut):
                do {
                    try hotKeys?.register(
                        shortcut, name: "input source hotkey", context: context, handler: select)
                } catch {
                    context.logger.error(
                        "Input source hotkey failed: \(String(describing: error), privacy: .public)"
                    )
                }
            }
        }
        guard !taps.isEmpty else { return }
        context.installWhenTrusted("input mode taps") {
            do {
                try ModifierTap.install(name: "input mode taps", context: context, bindings: taps)
                return true
            } catch {
                return false
            }
        }
    }

    private func startRemaps(_ settings: RemapSettings, context: ModuleContext) {
        guard let remapper = KeyboardRemapper(settings: settings) else { return }
        context.own(.other, "caps lock remap") { remapper.stop() }
        context.observe(
            NSApplication.willTerminateNotification, on: .default, reading: \.name
        ) { _ in remapper.stop() }
        let onTap = settings.tap.map { tap in
            { @MainActor (flags: CGEventFlags) in
                tap.perform(holding: flags, showMado: showLauncher)
            }
        }
        guard settings.capsLock == .hyper else {
            remapper.start()
            if settings.capsLock == .control, let onTap {
                context.installWhenTrusted("caps lock tap") {
                    installCapsLockTap(onTap, context: context)
                }
            }
            return
        }
        context.installWhenTrusted("hyper key") {
            do {
                try HyperKey.install(name: "hyper key", context: context, onTap: onTap)
                remapper.start()
                return true
            } catch {
                return false
            }
        }
    }

    private func installCapsLockTap(
        _ onTap: @escaping @MainActor (CGEventFlags) -> Void, context: ModuleContext
    ) -> Bool {
        do {
            try ModifierTap.install(
                name: "caps lock tap", context: context,
                bindings: [ModifierTap.Tap(.rightControl): { onTap([]) }])
            return true
        } catch {
            return false
        }
    }
}
