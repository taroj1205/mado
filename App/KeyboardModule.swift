import AppCore
import InputKit
import os

struct KeyboardModule: Module {
    static let id = "keyboard"

    let descriptor: ModuleDescriptor
    let settings: @MainActor () -> InputSourceSettings

    func start(context: ModuleContext) {
        context.installWhenTrusted("input mode taps") { installTap(context) }
        AppInputSwitch.install(context: context, settings: settings)
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
}
