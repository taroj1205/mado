import AppCore
import InputKit
import os

struct KeyboardModule: Module {
    static let id = "keyboard"

    let descriptor: ModuleDescriptor

    func start(context: ModuleContext) {
        context.installWhenTrusted("input mode taps") { installTap(context) }
    }

    func stop() {
        Log.logger(descriptor.id).debug("Stopped")
    }

    private func installTap(_ context: ModuleContext) -> Bool {
        do {
            try ModifierTap.install(
                name: "input mode taps", context: context,
                bindings: [
                    .single(.leftCommand): { InputMode.english.select() },
                    .single(.rightCommand): { InputMode.japanese.select() },
                ])
            return true
        } catch {
            return false
        }
    }
}
