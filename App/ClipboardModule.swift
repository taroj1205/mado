import AppCore
import ClipboardKit
import os

struct ClipboardModule: Module {
    static let id = "clipboard"

    let descriptor: ModuleDescriptor

    func start(context: ModuleContext) {
        let logger = context.logger
        PasteboardWatch.install(name: "pasteboard watch", context: context) {
            logger.debug("Pasteboard changed")
        }
        logger.debug("Started")
    }

    func stop() {
        Log.logger(descriptor.id).debug("Stopped")
    }
}
