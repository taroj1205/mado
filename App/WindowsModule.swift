import AppCore
import GlassUI
import os

struct WindowsModule: Module {
    static let id = "windows"

    let descriptor: ModuleDescriptor
    let radialRing = OverlayPanel()
    let radialPreview = OverlayPanel()

    func start(context: ModuleContext) {
        context.logger.debug("Started")
    }

    func stop() {
        Log.logger(descriptor.id).debug("Stopped")
    }
}
