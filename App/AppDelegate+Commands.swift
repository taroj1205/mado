import AppCore

extension AppDelegate {
    var appCommands: [Command] {
        [
            Command(
                id: "mado.settings", name: "Mado Settings", icon: "gearshape",
                actions: [
                    CommandAction(id: "open", title: "Open Mado Settings") { [weak self] in
                        self?.showSettings()
                    }
                ],
                keywords: ["preferences", "options", "configure"]),
            Command(
                id: "widgets.edit", name: "Edit Widgets", icon: "square.grid.2x2",
                actions: [
                    CommandAction(id: "edit", title: "Edit Widgets") { [weak self] in
                        self?.editWidgetsInLauncher()
                    }
                ],
                keywords: ["widgets", "arrange", "customize", "customise"]),
            Command(
                id: "widgets.add", name: "Add Widgets", icon: "plus.square",
                actions: [
                    CommandAction(id: "add", title: "Add Widgets") { [weak self] in
                        self?.editWidgetsInLauncher()
                    }
                ],
                keywords: ["widgets", "gallery", "new"]),
        ]
    }
}
