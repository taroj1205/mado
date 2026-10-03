import AppCore
import InputKit
import os

struct KeyboardModule: Module {
    static let id = "keyboard"

    let descriptor: ModuleDescriptor
    let remapSettings: @MainActor () -> RemapSettings

    func start(context: ModuleContext) {
        context.installWhenTrusted("input mode taps") { installTap(context) }
        startRemap(remapSettings(), context: context)
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

    private func startRemap(_ settings: RemapSettings, context: ModuleContext) {
        let logger = context.logger
        context.own(.other, "caps lock remap") {
            if !CapsLockRemap.restore() {
                logger.error("Caps Lock mapping was not restored")
            }
        }
        guard settings.capsLock == .hyper else {
            apply(settings.capsLock, logger: logger)
            return
        }
        context.installWhenTrusted("hyper key") {
            do {
                try HyperKey.install(
                    name: "hyper key", context: context, tapsEscape: settings.tapsEscape)
            } catch {
                return false
            }
            apply(.hyper, logger: logger)
            return true
        }
    }

    private func apply(_ remap: CapsLockRemap, logger: Logger) {
        if !remap.apply() {
            logger.error("Caps Lock remap to \(remap.rawValue, privacy: .public) failed")
        }
    }
}
