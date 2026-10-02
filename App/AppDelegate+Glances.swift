import AppCore
import GlassUI

extension AppDelegate {
    func connectGlances() {
        launcherView.onPill = { [weak self] pill in
            self?.runGlance(StatusPills.action(for: pill), for: pill.id)
        }
        launcherView.onWidget = { [weak self] widget in
            self?.runGlance(Widgets.action(for: widget), for: widget.id)
        }
    }

    func showGlances() {
        widgets.show(in: launcherView)
        systemFeed.start { [weak self] stats in
            guard let self else { return }
            launcherView.pills = StatusPills.pills(for: stats)
            widgets.show(stats, in: launcherView)
        }
    }

    func hideGlances() {
        systemFeed.stop()
        widgets.stop()
    }

    private func runGlance(_ action: CommandAction, for id: String) {
        hideLauncher()
        perform(action, for: id, recordingUse: false)
    }
}
