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
        id == KeyboardModule.id
            ? KeyboardModule(descriptor: self) : PlaceholderModule(descriptor: self)
    }
}
