import AppCore
import AppKit
import InputKit
import os

struct KeyboardModule: Module {
    static let id = "keyboard"

    let descriptor: ModuleDescriptor
    let inputSourceSettings: @MainActor () -> InputSourceSettings
    let remapSettings: @MainActor () -> RemapSettings
    let openLauncher: @MainActor () -> Void

    func start(context: ModuleContext) {
        context.startKeyFeatures {
            context.installWhenTrusted("input mode taps") { installTap(context) }
            AppInputSwitch.install(context: context, settings: inputSourceSettings)
            startRemaps(remapSettings(), context: context)
        }
    }

    func stop() {
        Log.logger(descriptor.id).debug("Stopped")
    }

    private func installTap(_ context: ModuleContext) -> Bool {
        do {
            try ModifierTap.install(
                name: "input mode taps", context: context,
                bindings: [
                    ModifierTap.Tap(.leftCommand): { InputMode.english.select() },
                    ModifierTap.Tap(.rightCommand): { InputMode.japanese.select() },
                ])
            return true
        } catch {
            return false
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
                tap.perform(holding: flags, openMado: openLauncher)
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
