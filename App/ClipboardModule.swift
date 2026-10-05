import AppCore
import AppKit
import ClipboardKit
import os

struct ClipboardModule: Module {
    struct Screens {
        let history: ClipboardHistory
        let textTools: TextTools
        let emoji: EmojiPicker
    }

    static let id = "clipboard"
    static let commandIDs =
        [ClipboardHistory.commandID, EmojiPicker.commandID, PasteStack.commandID]
        + TextTools.commandIDs
    private static let pruneInterval: TimeInterval = 3_600

    let descriptor: ModuleDescriptor
    let settings: @MainActor () -> ClipboardSettings
    let screens: Screens
    let snippets: Snippets
    let pasteStack = PasteStack()

    private static func recognizeImages(
        in store: ClipboardStore, for history: ClipboardHistory, logger: Logger
    ) async {
        do {
            try await store.recognizeImages { await history.entriesChanged() }
        } catch {
            logger.error("Recognising image text failed: \(error, privacy: .public)")
        }
    }

    func start(context: ModuleContext) {
        let logger = context.logger
        let store: ClipboardStore
        do {
            store = try .standard()
        } catch {
            logger.error("Clipboard history failed to open: \(error, privacy: .public)")
            return
        }
        screens.history.start(with: store, context: context)
        screens.textTools.start(with: store, context: context)
        screens.emoji.start(context: context)
        pasteStack.start(context: context)
        keepPruned(store, in: context)
        context.run("recognize image text") {
            await Self.recognizeImages(in: store, for: screens.history, logger: logger)
        }
        snippets.checkCopies(with: watchCopies(into: store, context: context))
        context.own(.other, "snippet copy check") { [snippets] in snippets.checkCopies(with: nil) }
        logger.debug("Started")
    }

    func stop() {
        Log.logger(descriptor.id).debug("Stopped")
    }

    private func watchCopies(
        into store: ClipboardStore, context: ModuleContext
    ) -> @MainActor () -> Void {
        let logger = context.logger
        let readSettings = settings
        let stack = pasteStack
        return PasteboardWatch.install(name: "pasteboard watch", context: context) { sources in
            let apps = sources.isEmpty ? "an unknown app" : sources.joined(separator: " or ")
            let current = readSettings()
            if current.ignores(any: sources) {
                logger.debug("Skipped a copy from \(apps, privacy: .public), which is ignored")
                return
            }
            let source = sources.count == 1 ? sources.first : nil
            guard let clip = Clip(reading: .general, source: source, at: .now) else {
                logger.debug("Skipped a copy with nothing to keep")
                return
            }
            stack.add(clip)
            let retention = current.retention
            context.run("save copy") {
                do {
                    try await store.add(clip, keeping: retention)
                } catch {
                    logger.error("Saving a copy failed: \(error, privacy: .public)")
                    return
                }
                if clip.kind == .image {
                    await Self.recognizeImages(in: store, for: screens.history, logger: logger)
                }
            }
        }
    }

    private func keepPruned(_ store: ClipboardStore, in context: ModuleContext) {
        let logger = context.logger
        let prune: @MainActor @Sendable () -> Void = { [settings, weak context] in
            let retention = settings().retention
            context?.run("prune clipboard history") {
                do {
                    try await store.prune(keeping: retention, now: .now)
                } catch {
                    logger.error("Pruning clipboard history failed: \(error, privacy: .public)")
                }
            }
        }
        prune()
        context.scheduleTimer(
            "clipboard history expiry", interval: Self.pruneInterval, handler: prune)
    }
}
