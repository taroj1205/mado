import AppKit
import GlassUI

extension AppDelegate {
    func connectCamera() {
        cameraMirror.onOpen = { [weak self] in self?.openCamera() }
        cameraMirror.onPopOut = { [weak self] in self?.hideLauncher() }
    }

    private func openCamera() {
        let visible = launcher?.isVisible == true
        if visible, scope == .camera {
            hideLauncher()
            return
        }
        if !visible {
            showLauncher()
        }
        editor.close()
        enteredScope = .camera
        launcherView.enter(placeholder: CameraMirror.placeholder)
        cameraMirror.openInline()
    }
}
