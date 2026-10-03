import AppCore
import AppKit
import GlassUI
import WindowKit

extension AppDelegate {
    private static let launcherWidth: CGFloat = 760
    private static let launcherHeight: CGFloat = 476
    private static let gridLauncherHeight: CGFloat = 548
    private static let half: CGFloat = 0.5

    var widgetPlacement: WidgetPlacement? {
        modules?.isEnabled(Widgets.moduleID) == false ? nil : .load(from: modules)
    }

    var launcherSize: CGSize {
        let grid = launcherView.widgetLayout == .grid
        return CGSize(
            width: Self.launcherWidth,
            height: grid ? Self.gridLauncherHeight : Self.launcherHeight)
    }

    func launcherFrame(in visible: CGRect) -> CGRect {
        ScreenGeometry.centeredFrame(of: launcherSize, in: visible)
            .offsetBy(dx: 0, dy: -launcherView.widgetOverhang * Self.half)
    }

    func connectGlances() {
        launcherView.statusLayout = .load(from: modules)
        launcherView.onStatusLayout = { [weak self] layout in layout.save(to: self?.modules) }
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
        connectWidgetEditing()
    }

    private func connectWidgetEditing() {
        launcherView.onWidgetEdit = { [weak self] edit in
            guard let self else { return }
            Widgets.edit(edit, in: modules)
            launcherGallery?.refresh()
            widgetsChanged()
        }
        launcherView.onAddWidgets = { [weak self] in
            guard let self, let window = unsafe launcherView.window else { return }
            let gallery = launcherGallery ?? makeLauncherGallery()
            launcherGallery = gallery
            gallery.show(over: window, below: window.frame.minY + launcherView.widgetsBottom)
        }
        launcherView.onEndEditingWidgets = { [weak self] in self?.launcherGallery?.close() }
    }

    private func makeLauncherGallery() -> WidgetGalleryWindow {
        let gallery = WidgetGalleryWindow(modules: modules)
        gallery.onChange = { [weak self] in self?.widgetsChanged() }
        gallery.onClose = { [weak self] in
            guard let self, launcherView.editingWidgets, let window = unsafe launcherView.window
            else { return }
            window.makeKey()
        }
        return gallery
    }

    private func widgetsChanged() {
        widgets.show(Widgets.added(in: modules), in: launcherView)
    }

    func showGlances() {
        widgets.shown = Widgets.added(in: modules)
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
