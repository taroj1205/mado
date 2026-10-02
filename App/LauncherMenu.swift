import AppCore
import AppKit
import GlassUI
import SearchKit

@MainActor
struct LauncherMenu {
    enum Entry {
        case run(CommandAction, keys: [String], isDestructive: Bool)
        case openWith(URL)
        case edit(ItemEditor.Edit)
    }

    let groups: [[Entry]]
    let recordsUse: Bool

    init(actions: [CommandAction]) {
        self.init(groups: [Self.entries(for: actions)], recordsUse: false)
    }

    init(for id: String, query: String, in sources: LauncherResult.Sources, editor: ItemEditor) {
        let actions = LauncherResult.actions(for: id, query: query, in: sources)
        guard let result = LauncherResult.result(for: id, in: sources) else {
            self.init(actions: actions)
            return
        }
        var main = Self.entries(for: actions)
        var quit: [Entry] = []
        switch result {
        case .app(let app):
            main += Self.pathEntries(for: app.url)
            if let action = FileActions.quit(appAt: app.url) {
                quit = [.run(action, keys: FileActions.quitKeys, isDestructive: true)]
            }

        case .file(let file):
            main += [.openWith(file.url)] + Self.pathEntries(for: file.url)

        case .command, .pane, .quicklink:
            break
        }
        self.init(groups: [main, editor.edits(for: id).map(Entry.edit), quit], recordsUse: true)
    }

    private init(groups: [[Entry]], recordsUse: Bool) {
        self.groups = groups
        self.recordsUse = recordsUse
    }

    private static func entries(for actions: [CommandAction]) -> [Entry] {
        let keys = [LauncherView.Action.primaryKeys, LauncherView.Action.secondaryKeys]
        return actions.enumerated().map { index, action in
            .run(
                action, keys: keys.indices.contains(index) ? keys[index] : [],
                isDestructive: false)
        }
    }

    private static func pathEntries(for url: URL) -> [Entry] {
        [
            .run(FileActions.showInfo(url), keys: FileActions.showInfoKeys, isDestructive: false),
            .run(FileActions.copyPath(url), keys: FileActions.copyPathKeys, isDestructive: false),
        ]
    }

    func actions(
        labelling label: (ItemEditor.Edit) -> LauncherView.Action,
        running run: @escaping @MainActor (CommandAction, _ recordingUse: Bool) -> Void
    ) -> [LauncherView.Action] {
        groups.enumerated().flatMap { group, entries in
            entries.map { entry in
                var action =
                    switch entry {
                    case let .run(action, keys, isDestructive):
                        LauncherView.Action(action.title, keys: keys, isDestructive: isDestructive)

                    case .openWith(let url):
                        LauncherView.Action(FileActions.openWithTitle) {
                            choices(opening: url, running: run)
                        }

                    case .edit(let edit):
                        label(edit)
                    }
                action.group = group
                return action
            }
        }
    }

    private func choices(
        opening url: URL, running run: @escaping @MainActor (CommandAction, Bool) -> Void
    ) -> [ActionChoice] {
        FileActions.applications(toOpen: url).map { app in
            let action = FileActions.open(url, with: app)
            return ActionChoice(action.title, icon: NSWorkspace.shared.icon(forFile: app.path)) {
                run(action, recordsUse)
            }
        }
    }

    func entry(at index: Int) -> Entry? {
        let entries = groups.flatMap(\.self)
        return entries.indices.contains(index) ? entries[index] : nil
    }
}
