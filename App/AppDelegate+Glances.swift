import AppCore
import AppKit
import GlassUI
import WindowKit

extension AppDelegate {
    private static let launcherWidth: CGFloat = 760
    private static let launcherHeight: CGFloat = 476
    private static let gridLauncherHeight: CGFloat = 548
    private static let half: CGFloat = 0.5

    var launcherSize: CGSize {
        CGSize(
            width: Self.launcherWidth,
            height: launcherView.widgetsFillPanel ? Self.gridLauncherHeight : Self.launcherHeight)
    }

    func arrangeWidgets() {
        let shown = modules?.isEnabled(Widgets.moduleID) != false
        launcherView.widgetLayout = shown ? WidgetInlineStyle.load(from: modules).layout : nil
        launcherView.widgetSpots = WidgetSettings.load(from: modules).spots(
            WidgetPlacement.load(from: modules).arrangement, from: Widgets.ids)
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
                runGlance(widgets.action(for: widget), for: widget.id)
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
        arrangeWidgets()
        widgets.show(Widgets.added(in: modules), in: launcherView)
    }

    func showGlances() {
        let enabled = modules?.isEnabled(Widgets.moduleID) != false
        widgets.shown = enabled ? Widgets.added(in: modules) : []
        widgets.city = WeatherSettings.load(from: modules).city
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
