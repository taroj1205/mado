import AppCore
import ClipboardKit
import os

struct ClipboardModule: Module {
    static let id = "clipboard"

    let descriptor: ModuleDescriptor
    let settings: @MainActor () -> ClipboardSettings

    func start(context: ModuleContext) {
        let logger = context.logger
        PasteboardWatch.install(name: "pasteboard watch", context: context) { [settings] sources in
            let apps = sources.isEmpty ? "an unknown app" : sources.joined(separator: " or ")
            if settings().ignores(any: sources) {
                logger.debug("Skipped a copy from \(apps, privacy: .public), which is ignored")
                return
            }
            logger.debug("Pasteboard changed in \(apps, privacy: .public)")
        }
        logger.debug("Started")
    }

    func stop() {
        Log.logger(descriptor.id).debug("Stopped")
    }
}
