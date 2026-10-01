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
