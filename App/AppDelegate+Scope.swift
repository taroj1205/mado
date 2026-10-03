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
    }

    var scope: Scope {
        guard launcherView.scoped else { return .root }
        return clipboardScoped ? .clipboard : .calculator
    }

    func connectClipboardHistory() {
        clipboardHistory.onOpen = { [weak self] in self?.openClipboardHistory() }
        clipboardHistory.onFilter = { [weak self] in self?.searchAgain() }
        clipboardHistory.onRunningChange = { [weak self] in
            guard let self else { return }
            if !clipboardHistory.isRunning, scope == .clipboard {
                launcherView.leave()
            }
            editor.refreshHotKey(for: ClipboardHistory.commandID)
        }
    }

    func results(for query: String) async -> [ResultList.Section] {
        switch scope {
        case .clipboard:
            return await clipboardHistory.sections(for: query)

        case .calculator:
            return history.sections(for: query)

        case .root:
            return signposter.withIntervalSignpost("search") {
                LauncherResult.sections(for: query, in: sources, usage: usage)
            }
        }
    }

    func menu(for item: ResultList.Item) -> LauncherMenu {
        switch scope {
        case .clipboard:
            LauncherMenu(unkeyed: clipboardHistory.actions(for: item.id))

        case .calculator:
            LauncherMenu(actions: history.actions(for: item.id))

        case .root:
            LauncherMenu(
                for: item.id, query: launcherView.field.stringValue, in: sources, editor: editor,
                pastingInto: pasteTarget)
        }
    }

    func show(_ sections: [ResultList.Section]) {
        launcherView.show(sections)
        (launcherView.context, launcherView.contextSymbol) =
            switch scope {
            case .clipboard:
                (ClipboardHistory.title, ClipboardHistory.symbol)

            case .calculator:
                (CalculatorHistory.title, CalculatorHistory.symbol)

            case .root:
                LauncherResult.context(for: sections, query: launcherView.field.stringValue)
            }
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
        clipboardScoped = true
        launcherView.enter(
            placeholder: ClipboardHistory.placeholder, filter: clipboardHistory.filter
        ) { [clipboardHistory] in clipboardHistory.preview(for: $0) }
    }
}
