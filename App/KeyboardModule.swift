import AppCore
import InputKit
import os

struct KeyboardModule: Module {
    static let id = "keyboard"

    let descriptor: ModuleDescriptor
    let inputSourceSettings: @MainActor () -> InputSourceSettings
    let remapSettings: @MainActor () -> RemapSettings

    func start(context: ModuleContext) {
        context.installWhenTrusted("input mode taps") { installTap(context) }
        AppInputSwitch.install(context: context, settings: inputSourceSettings)
        startRemaps(remapSettings(), context: context)
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
        guard settings.capsLock == .hyper else {
            remapper.start()
            return
        }
        context.installWhenTrusted("hyper key") {
            do {
                try HyperKey.install(
                    name: "hyper key", context: context, tapSendsEscape: settings.tapSendsEscape)
                remapper.start()
                return true
            } catch {
                return false
            }
        }
    }
}
