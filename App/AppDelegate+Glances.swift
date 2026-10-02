import AppCore
import AppKit
import GlassUI

extension AppDelegate {
    private static let launcherWidth: CGFloat = 760
    private static let launcherHeight: CGFloat = 476
    private static let gridLauncherHeight: CGFloat = 548

    var widgetPlacement: WidgetPlacement? {
        modules?.isEnabled(Widgets.moduleID) == false ? nil : .load(from: modules)
    }

    var launcherSize: CGSize {
        let grid = launcherView.widgetLayout == .grid
        return CGSize(
            width: Self.launcherWidth,
            height: grid ? Self.gridLauncherHeight : Self.launcherHeight)
    }

    func connectGlances() {
        launcherView.onPill = { [weak self] pill in
            self?.runGlance(StatusPills.action(for: pill), for: pill.id)
        }
        launcherView.onWidget = { [weak self] widget in
            guard let self else { return }
            if widget.id == Widgets.music {
                widgets.control(.playPause, in: launcherView)
            } else {
                runGlance(Widgets.action(for: widget), for: widget.id)
            }
        }
        launcherView.onSkip = { [weak self] skip in
            guard let self else { return }
            widgets.control(skip == .previous ? .previous : .next, in: launcherView)
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
