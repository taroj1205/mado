import AppKit
import GlassUI

extension AppDelegate {
    func windowDidResignKey(_: Notification) {
        guard !launcherView.sharing, !cameraMirror.isRequestingAccess else { return }
        #if DEBUG
            if KeepLauncherOpen.isEnabled { return }
        #endif
        hideLauncher()
    }

    #if DEBUG
        func applicationDidResignActive(_: Notification) {
            guard !KeepLauncherOpen.isEnabled, !launcherView.sharing,
                !cameraMirror.isRequestingAccess
            else { return }
            if launcher?.isVisible == true { hideLauncher() }
        }
    #endif
}
