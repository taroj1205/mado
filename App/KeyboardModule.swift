import AppCore
import InputKit
import os

struct KeyboardModule: Module {
    static let id = "keyboard"
    private static let retryInterval: Duration = .seconds(1)

    let descriptor: ModuleDescriptor

    func start(context: ModuleContext) {
        guard !installTap(context) else { return }
        context.logger.notice("Input mode taps wait for Accessibility")
        context.run("wait for Accessibility") {
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.retryInterval)
                if !Task.isCancelled, installTap(context) { return }
            }
        }
    }

    func stop() {
        Log.logger(descriptor.id).debug("Stopped")
    }

    private func installTap(_ context: ModuleContext) -> Bool {
        do {
            try ModifierTap.install(name: "input mode taps", context: context) { key in
                switch key {
                case .leftCommand: InputMode.english.select()
                case .rightCommand: InputMode.japanese.select()
                default: break
                }
            }
            return true
        } catch {
            return false
        }
    }
}
