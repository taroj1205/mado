import AppKit
import GlassUI

extension AppDelegate {
    func windowDidResignKey(_: Notification) {
        guard !launcherView.sharing else { return }
        #if DEBUG
            if KeepLauncherOpen.isEnabled { return }
        #endif
        hideLauncher()
    }

    #if DEBUG
        func applicationDidResignActive(_: Notification) {
            if !KeepLauncherOpen.isEnabled, !launcherView.sharing, launcher?.isVisible == true {
                hideLauncher()
            }
        }
    #endif
}
