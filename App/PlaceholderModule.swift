import AppCore
import InputKit
import os

struct PlaceholderModule: Module {
    let descriptor: ModuleDescriptor

    func start(context: ModuleContext) {
        context.logger.debug("Started")
    }

    func stop() {
        Log.logger(descriptor.id).debug("Stopped")
    }
}

extension ModuleDescriptor {
    @MainActor
    func makeModule(
        in modules: ModuleManager, hotKeys: HotKeyRegistry?, clipboardHistory: ClipboardHistory
    ) -> any Module {
        switch id {
        case ClipboardModule.id:
            ClipboardModule(
                descriptor: self, settings: { [weak modules] in .load(from: modules) },
                history: clipboardHistory)

        case KeyboardModule.id:
            KeyboardModule(descriptor: self) { [weak modules] in .load(from: modules) }

        case WindowsModule.id:
            WindowsModule(
                descriptor: self, hotKeys: hotKeys,
                layoutSettings: { [weak modules] in .load(from: modules) },
                radialSettings: { [weak modules] in .load(from: modules) },
                gestureSettings: { [weak modules] in .load(from: modules) },
                switcherSettings: { [weak modules] in .load(from: modules) })

        default: PlaceholderModule(descriptor: self)
        }
    }
}
