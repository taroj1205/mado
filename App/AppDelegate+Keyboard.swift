extension AppDelegate {
    var keyboardLauncher: KeyboardModule.Launcher {
        .init(
            show: { [weak self] toggles in
                if toggles {
                    self?.toggleLauncher()
                } else {
                    self?.showLauncher()
                }
            },
            run: { [weak self] id in self?.runHotKey(of: id) })
    }
}
