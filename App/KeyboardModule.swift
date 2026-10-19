import AppCore
import AppKit
import GlassUI
import InputKit
import os

struct KeyboardModule: Module {
    struct Launcher {
        let show: @MainActor (_ toggles: Bool) -> Void
        let run: @MainActor (_ id: String) -> Void
    }

    static let id = "keyboard"
    private static let inputTapMilliseconds = 500

    let descriptor: ModuleDescriptor
    let hotKeys: HotKeyRegistry?
    let inputSourceSettings: @MainActor () -> InputSourceSettings
    let modifierBindings: @MainActor () -> ModifierBindings
    let remapSettings: @MainActor () -> RemapSettings
    let enterGuardSettings: @MainActor () -> EnterGuardSettings
    let launcher: Launcher
    let inputMemory = AppInputSwitch.Memory()

    func start(context: ModuleContext) {
        AppInputSwitch.trackActivationsWhileStopped(context: context, memory: inputMemory)
        context.startKeyFeatures {
            let remaps = remapSettings()
            let inputSources = inputSourceSettings()
            installInputShortcuts(inputSources.keys, context: context)
            let assignments = TapAssignments(
                inputSources: inputSources, bindings: modifierBindings())
            installModifierTaps(
                assignments.entries.filter { !remaps.claims($0.tap) }, context: context)
            AppInputSwitch.install(
                context: context, settings: inputSourceSettings, memory: inputMemory)
            startRemaps(remaps, context: context)
            startEnterGuard(enterGuardSettings(), context: context)
        }
    }

    func stop() {
        Log.logger(descriptor.id).debug("Stopped")
    }

    private func installInputShortcuts(_ keys: [InputKey], context: ModuleContext) {
        for key in keys {
            guard case .shortcut(let shortcut) = key.hotKey else { continue }
            do {
                try hotKeys?.register(
                    shortcut, name: "input source hotkey", context: context,
                    handler: perform(.inputSource(target: key.target)))
            } catch {
                context.logger.error(
                    "Input source hotkey failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    private func installModifierTaps(_ entries: [ModifierBindings.Entry], context: ModuleContext) {
        let taps = Dictionary(entries.map { ($0.tap, perform($0.action)) }) { first, _ in first }
        guard !taps.isEmpty else { return }
        context.installWhenTrusted("modifier taps") {
            do {
                try ModifierTap.install(
                    name: "modifier taps", context: context, bindings: taps,
                    window: .milliseconds(Self.inputTapMilliseconds))
                return true
            } catch {
                return false
            }
        }
    }

    private func perform(_ action: ModifierAction) -> @MainActor () -> Void {
        { [launcher] in
            guard !(NSApp.keyWindow?.firstResponder is HotKeyRecorder) else { return }
            switch action {
            case .inputSource(let target): target.select()
            case .item(let id): launcher.run(id)
            }
        }
    }

    private func startEnterGuard(_ settings: EnterGuardSettings, context: ModuleContext) {
        guard settings.isOn else { return }
        context.installWhenTrusted("enter guard") {
            do {
                try EnterGuard.install(name: "enter guard", context: context, settings: settings)
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
                tap.perform(holding: flags, showMado: launcher.show)
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
