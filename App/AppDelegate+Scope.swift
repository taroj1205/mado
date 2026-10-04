import AppKit
import ClipboardKit
import GlassUI
import os
import SearchKit

extension AppDelegate {
    enum Scope {
        case root
        case calculator
        case clipboard
        case textTools
        case emoji
    }

    private static let clipboardScopes: Set<Scope> = [.clipboard, .textTools, .emoji]

    var scope: Scope {
        launcherView.scoped ? enteredScope : .root
    }

    private var emojiGridHome: String? {
        switch scope {
        case .emoji:
            ""

        case .root where emojiPicker.query(in: launcherView.field.stringValue) != nil:
            EmojiPicker.prefix

        default:
            nil
        }
    }

    func connectClipboardHistory() {
        clipboardHistory.onOpen = { [weak self] in self?.openClipboardHistory() }
        clipboardHistory.onChange = { [weak self] in
            if self?.scope == .clipboard { self?.searchAgain() }
        }
        clipboardHistory.onCount = { [weak self] in
            if self?.scope == .clipboard { self?.launcherView.refreshDetail() }
        }
        clipboardHistory.onRunningChange = { [weak self] in self?.clipboardRunningChanged() }
        textTools.onOpen = { [weak self] in self?.openTextTools() }
        textTools.findTarget = { [weak self] in
            PasteTarget.frontmost() ?? (self?.launcher?.isVisible == true ? self?.pasteTarget : nil)
        }
        launcherView.onLeave = { [weak self] in
            self?.clipboardHistory.close()
            self?.textTools.close()
        }
        clipboardRunningChanged()
    }

    func results(for query: String) async -> [ResultList.Section] {
        switch scope {
        case .clipboard:
            return await clipboardHistory.sections(for: query, pastingInto: pasteTarget)

        case .textTools:
            return textTools.sections(for: query)

        case .emoji:
            return emojiPicker.sections(for: query, pastingInto: pasteTarget)

        case .calculator:
            return history.sections(for: query)

        case .root:
            if let emoji = emojiPicker.query(in: query) {
                return emojiPicker.sections(for: emoji, pastingInto: pasteTarget)
            }
            let state = signposter.beginInterval("search")
            defer { signposter.endInterval("search", state) }
            return await LauncherResult.sections(for: query, in: sources, usage: usage)
        }
    }

    func menu(for item: ResultList.Item) -> LauncherMenu {
        if EmojiPicker.owns(item.id) {
            return LauncherMenu(keyed: emojiPicker.actions(for: item.id, pastingInto: pasteTarget))
        }
        return switch scope {
        case .clipboard:
            LauncherMenu(keyed: clipboardHistory.actions(for: item.id, pastingInto: pasteTarget))

        case .textTools:
            LauncherMenu(keyed: textTools.actions(for: item.id))

        case .emoji:
            LauncherMenu(actions: [])

        case .calculator:
            LauncherMenu(actions: history.actions(for: item.id))

        case .root:
            LauncherMenu(
                for: item.id, query: launcherView.field.stringValue, in: sources, editor: editor,
                pastingInto: pasteTarget)
        }
    }

    func connectActions() {
        launcherView.actions = { [weak self] in self?.launcherActions(for: $0) ?? [] }
        launcherView.shortcutKeys = LauncherMenu.shortcutKeys + ColourAnswer.shortcutKeys
    }

    private func capsuleSlots(showingGrid: Bool) -> [LauncherView.CapsuleSlot] {
        if showingGrid {
            EmojiPicker.capsule
        } else if scope == .textTools {
            TextTools.capsule
        } else {
            LauncherView.CapsuleSlot.standard
        }
    }

    func show(_ sections: [ResultList.Section]) {
        let home = emojiGridHome
        launcherView.capsuleSlots = capsuleSlots(showingGrid: home != nil)
        launcherView.show(sections, gridHome: home)
        (launcherView.context, launcherView.contextSymbol) =
            switch scope {
            case .clipboard:
                (ClipboardHistory.title, ClipboardHistory.symbol)

            case .textTools:
                (TextTools.title, TextTools.symbol)

            case .emoji:
                (EmojiPicker.title, nil)

            case .calculator:
                (CalculatorHistory.title, CalculatorHistory.symbol)

            case .root:
                LauncherResult.context(for: sections, query: launcherView.field.stringValue)
            }
    }

    private func clipboardRunningChanged() {
        if clipboardHistory.isRunning {
            if ClipboardHistory.assignDefaultHotKey(in: editor, modules: modules) {
                settings?.reload()
            }
            if scope == .clipboard {
                searchAgain()
            }
        } else if Self.clipboardScopes.contains(scope) {
            DispatchQueue.main.async { [weak self] in
                guard let self, !clipboardHistory.isRunning, Self.clipboardScopes.contains(scope)
                else { return }
                launcherView.leave()
            }
        }
        ClipboardModule.commandIDs.forEach(editor.refreshHotKey)
    }

    func openCalculatorHistory() {
        enteredScope = .calculator
        launcherView.enter(placeholder: CalculatorHistory.placeholder)
    }

    private func openClipboardHistory() {
        let visible = launcher?.isVisible == true
        if visible, scope == .clipboard {
            hideLauncher()
            return
        }
        if !visible {
            showLauncher()
        }
        editor.close()
        enteredScope = .clipboard
        launcherView.enter(
            placeholder: ClipboardHistory.placeholder, filter: clipboardHistory.filter,
            detail: .preview { [clipboardHistory] in clipboardHistory.preview(for: $0) })
    }

    private func openTextTools() {
        if launcher?.isVisible != true {
            showLauncher()
        }
        editor.close()
        enteredScope = .textTools
        launcherView.enter(
            placeholder: TextTools.placeholder, chip: TextTools.chip,
            detail: .comparison { [textTools] in textTools.comparison(for: $0) })
    }

    func queryChanged() {
        textTools.cancelOpening()
        searchAgain()
    }
}
