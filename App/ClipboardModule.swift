import AppCore
import AppKit
import ClipboardKit
import os

struct ClipboardModule: Module {
    static let id = "clipboard"

    let descriptor: ModuleDescriptor
    let settings: @MainActor () -> ClipboardSettings

    func start(context: ModuleContext) {
        let logger = context.logger
        let store: ClipboardStore
        do {
            store = try .standard()
        } catch {
            logger.error("Clipboard history failed to open: \(error, privacy: .public)")
            return
        }
        let retention = ClipboardStore.Retention()
        context.run("prune clipboard history") {
            do {
                try await store.prune(keeping: retention, now: .now)
            } catch {
                logger.error("Pruning clipboard history failed: \(error, privacy: .public)")
            }
        }
        PasteboardWatch.install(name: "pasteboard watch", context: context) { [settings] sources in
            let apps = sources.isEmpty ? "an unknown app" : sources.joined(separator: " or ")
            if settings().ignores(any: sources) {
                logger.debug("Skipped a copy from \(apps, privacy: .public), which is ignored")
                return
            }
            let source = sources.count == 1 ? sources.first : nil
            guard let clip = Clip(reading: .general, source: source, at: .now) else {
                logger.debug("Skipped a copy with nothing to keep")
                return
            }
            context.run("save copy") {
                do {
                    try await store.add(clip, keeping: retention)
                } catch {
                    logger.error("Saving a copy failed: \(error, privacy: .public)")
                }
            }
        }
        logger.debug("Started")
    }

    func stop() {
        Log.logger(descriptor.id).debug("Stopped")
    }
}
