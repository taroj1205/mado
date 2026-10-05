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
        in modules: ModuleManager, hotKeys: HotKeyRegistry?, menuBar: MenuBarItems,
        clipboard: ClipboardModule.Screens,
        showLauncher: @escaping @MainActor (_ toggles: Bool) -> Void
    ) -> any Module {
        switch id {
        case ClipboardModule.id:
            ClipboardModule(
                descriptor: self, settings: { [weak modules] in .load(from: modules) },
                screens: clipboard)

        case DictationModule.id:
            DictationModule(descriptor: self) { [weak modules] in .load(from: modules) }

        case KeyboardModule.id:
            KeyboardModule(
                descriptor: self, hotKeys: hotKeys,
                inputSourceSettings: { [weak modules] in .load(from: modules) },
                remapSettings: { [weak modules] in .load(from: modules) },
                enterGuardSettings: { [weak modules] in .load(from: modules) },
                showLauncher: showLauncher)

        case WindowsModule.id:
            WindowsModule(
                descriptor: self, hotKeys: hotKeys,
                layoutSettings: { [weak modules] in .load(from: modules) },
                radialSettings: { [weak modules] in .load(from: modules) },
                gestureSettings: { [weak modules] in .load(from: modules) },
                switcherSettings: { [weak modules] in .load(from: modules) })

        case NotesModule.id:
            NotesModule(descriptor: self, menuBar: menuBar, modules: modules)

        default: PlaceholderModule(descriptor: self)
        }
    }
}
