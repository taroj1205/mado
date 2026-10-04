import AppKit
import GlassUI

extension AppDelegate {
    func windowDidResignKey(_: Notification) {
        guard !launcherView.sharing, launcherGallery?.isVisible != true else { return }
        #if DEBUG
            if KeepLauncherOpen.isEnabled { return }
        #endif
        hideLauncher()
    }

    func applicationDidResignActive(_: Notification) {
        #if DEBUG
            let hides = !KeepLauncherOpen.isEnabled
        #else
            let hides = launcherGallery?.isVisible == true
        #endif
        if hides, !launcherView.sharing, launcher?.isVisible == true { hideLauncher() }
    }
}
