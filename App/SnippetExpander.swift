import AppCore
import AppKit
import Carbon.HIToolbox
import ClipboardKit
import InputKit
import os
import WindowKit

@MainActor
final class SnippetExpander {
    private static let route = "snippet keywords"
    private static let types: [CGEventType] = [
        .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown,
    ]
    private static let keywordChecks = 5
    private static let keywordCheckMilliseconds = 30

    var settings: SnippetSettings {
        get { typing.settings }
        set { typing.settings = newValue }
    }

    private let logger: Logger
    private let fillIn = SnippetFillIn()
    private var typing = SnippetTyping()
    private var busy = false
    private var stopped = false

    init(logger: Logger) {
        self.logger = logger
    }

    func install(in context: ModuleContext) {
        context.installWhenTrusted(Self.route) { [weak self, weak context] in
            guard let context else { return true }
            do {
                try context.tapEvents(Self.route, matching: Self.types) { type, event in
                    self?.handle(type, event) ?? false
                }
                return true
            } catch {
                return false
            }
        }
        context.observe(
            NSWorkspace.didActivateApplicationNotification,
            on: NSWorkspace.shared.notificationCenter, reading: \.name
        ) { [weak self] _ in self?.forget() }
        context.observe(
            Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            on: DistributedNotificationCenter.default(), reading: \.name
        ) { [weak self] _ in self?.forget() }
        context.own(.other, "snippet fill-in") { [weak self] in
            self?.stopped = true
            self?.forget()
            self?.fillIn.close()
        }
    }

    func insert(_ snippet: Snippet, into target: PasteTarget) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            try await target.activate()
            await expand(snippet, replacing: "", in: target)
        } catch {
            logger.error("Pasting a snippet failed: \(error, privacy: .public)")
        }
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        let inMado = NSApp.keyWindow != nil
        if busy, inMado { return false }
        let canExpand = !busy && !inMado && !IsSecureEventInputEnabled()
        switch typing.handle(type, event, canExpand: canExpand) {
        case .pass:
            return false

        case .undo(let inserted):
            DispatchQueue.main.async { [weak self] in self?.undo(inserted) }
            return true

        case .expand(let snippet):
            busy = true
            Task { [weak self] in
                await self?.expandTyped(snippet)
                self?.busy = false
            }
            return false
        }
    }

    private func expandTyped(_ snippet: Snippet) async {
        guard let target = PasteTarget.frontmost(),
            settings.expands(in: target.app.bundleIdentifier), InputSource.currentTypesASCII
        else { return }
        await expand(snippet, replacing: snippet.keyword, in: target)
    }

    private func expand(_ snippet: Snippet, replacing typed: String, in target: PasteTarget) async {
        guard CGPreflightPostEventAccess() else {
            logger.notice("Snippets can’t type until Accessibility is allowed")
            return
        }
        let focused = await FocusedText.current(readingBack: typed.utf16.count)
        guard focused?.isSecure != true, !IsSecureEventInputEnabled() else { return }
        guard await isInPlace(typed, focused) else {
            logger.notice("The keyword isn’t plainly before the caret, so it wasn’t replaced")
            return
        }
        let template = SnippetTemplate(snippet.text)
        var fields: [String: String] = [:]
        do {
            if !template.fields.isEmpty {
                fields = try await fillIn.ask(snippet, template, under: focused?.caret)
                try await target.activate()
            }
            let clipboard = NSPasteboard.general.string(forType: .string) ?? ""
            let expansion = template.expand(.now(fields: fields, clipboard: clipboard))
            guard !stopped else { return }
            guard typed.isEmpty || (!typing.inputAfterMatch && target.app.isActive) else {
                logger.notice("Input moved on after the keyword, so it wasn’t replaced")
                return
            }
            let insertion = TextInsertion.standard
            let inserted = try insertion.replace(typed, with: expansion)
            typing.expanded(inserted)
            await insertion.restore(inserted)
        } catch is CancellationError {
            logger.debug("Fill-in fields were canceled; the keyword stays as typed")
        } catch {
            logger.error("Expanding a snippet failed: \(error, privacy: .public)")
        }
    }

    private func isInPlace(_ typed: String, _ focused: FocusedText?) async -> Bool {
        guard !typed.isEmpty else { return true }
        var focused = focused
        var keyword = TypedKeyword(
            typed, before: focused?.textBeforeCaret, selecting: focused?.selectsText == true)
        for _ in 0..<Self.keywordChecks where keyword == .arriving {
            try? await Task.sleep(for: .milliseconds(Self.keywordCheckMilliseconds))
            focused = await FocusedText.current(readingBack: typed.utf16.count)
            keyword = TypedKeyword(
                typed, before: focused?.textBeforeCaret, selecting: focused?.selectsText == true)
        }
        return keyword != .changed
    }

    private func undo(_ inserted: TextInsertion.Inserted) {
        do {
            try TextInsertion.standard.undo(inserted)
        } catch {
            logger.error("Undoing a snippet failed: \(error, privacy: .public)")
        }
    }

    private func forget() {
        typing.forget()
    }
}
