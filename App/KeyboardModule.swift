import AppCore
import AppKit
import InputKit
import os

struct KeyboardModule: Module {
    static let id = "keyboard"

    let descriptor: ModuleDescriptor
    let inputSources: @MainActor () -> AppInputSources

    func start(context: ModuleContext) {
        context.installWhenTrusted("input mode taps") { installTap(context) }
        followFrontmostApp(context)
    }

    func stop() {
        Log.logger(descriptor.id).debug("Stopped")
    }

    private func followFrontmostApp(_ context: ModuleContext) {
        let logger = context.logger
        var memory = AppInputSources.Memory(
            frontmost: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
        context.observe(
            "app input sources", NSWorkspace.didActivateApplicationNotification,
            in: NSWorkspace.shared.notificationCenter
        ) { [inputSources] in
            let app = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            guard
                let source = memory.activate(
                    app, leaving: InputSource.current?.id, with: inputSources())
            else { return }
            if !InputSource.select(id: source) {
                logger.error("Switching to \(source, privacy: .public) failed")
            }
        }
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
