import AppCore
import AppKit
import ClipboardKit
import GlassUI
import os
import WindowKit

@MainActor
final class PasteStack {
    static let commandID = "clipboard.paste-stack"
    private static let title = "Paste Stack"
    private static let route = "paste stack keys"
    private static let gap: CGFloat = 8
    private static let logger = Log.logger("PasteStack")

    private let hud = PasteStackHUD()
    private var queue: PasteQueue?
    private var listening = false

    func start(context: ModuleContext) {
        context.own(.other, "paste stack") { [weak self] in
            self?.listening = false
            self?.end()
        }
        let begin = CommandAction(id: "start", title: "Start \(Self.title)") { [weak self] in
            await self?.begin()
        }
        do {
            try context.register(
                Command(
                    id: Self.commandID, name: Self.title, icon: "square.stack", actions: [begin],
                    keywords: ["paste", "stack", "queue", "clipboard", "copy", "order"]))
        } catch {
            context.logger.error("Paste stack command failed: \(error, privacy: .public)")
        }
        context.startKeyFeatures { watchKeys(in: context) }
    }

    func add(_ clip: Clip) {
        guard queue != nil else { return }
        queue?.add(clip)
        refresh(near: nil)
    }

    private func watchKeys(in context: ModuleContext) {
        context.installWhenTrusted(Self.route) { [weak self, weak context] in
            guard let context else { return true }
            do {
                try context.tapEvents(Self.route, matching: [.keyDown]) { _, event in
                    self?.handle(event) ?? false
                }
                self?.listening = true
                return true
            } catch {
                return false
            }
        }
    }

    private func begin() async {
        guard listening else {
            Self.logger.notice("The paste stack waits for Accessibility to see ⌘V")
            NSSound.beep()
            return
        }
        end()
        let caret = await FocusedText.current(readingBack: 0)?.caret
        queue = PasteQueue()
        refresh(near: caret)
    }

    private func handle(_ event: CGEvent) -> Bool {
        guard queue != nil, NSApp.keyWindow == nil, let key = PasteQueue.key(for: event) else {
            return false
        }
        switch key {
        case .clear:
            end()
            return true

        case .paste:
            guard let next = queue?.takeNext() else { return false }
            do {
                try next.copy()
            } catch {
                Self.logger.error("Copying the next item failed: \(error, privacy: .public)")
                NSSound.beep()
                return true
            }
            if queue?.waiting.isEmpty == true {
                end()
            } else {
                refresh(near: nil)
            }
            return false
        }
    }

    private func refresh(near caret: CGRect?) {
        guard let queue else { return }
        let waiting = queue.waiting.enumerated().map { index, clip in
            PasteStackHUD.Row(title: clip.title, state: index == 0 ? .next : .waiting)
        }
        let pasted = queue.pasted.map { PasteStackHUD.Row(title: $0.title, state: .pasted) }
        hud.show(waiting + pasted, left: waiting.count) { size in
            let (anchor, screen) = CaretAnchor.find(caret)
            return ScreenGeometry.frame(
                of: size, below: anchor, gap: Self.gap, in: screen?.visibleFrame ?? anchor)
        }
    }

    private func end() {
        queue = nil
        hud.hide()
    }
}
