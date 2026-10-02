import AppCore
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
    func makeModule() -> any Module {
        switch id {
        case KeyboardModule.id: KeyboardModule(descriptor: self)
        case WindowsModule.id: WindowsModule(descriptor: self)
        default: PlaceholderModule(descriptor: self)
        }
    }
}
