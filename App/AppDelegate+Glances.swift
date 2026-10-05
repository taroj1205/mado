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
            height: gridHeight(
                otherwise: launcherView.editingWidgets || launcherView.widgetsFillPanel
                    || launcherView.showsCalendarAnswer
                    ? Self.gridLauncherHeight : Self.launcherHeight))
    }

    func arrangeWidgets() {
        let shown = modules?.isEnabled(Widgets.moduleID) != false
        launcherView.widgetLayout = shown ? WidgetInlineStyle.load(from: modules).layout : nil
        launcherView.opensWidgetsOnSingleClick =
            WidgetOpenGesture.load(from: modules) == .singleClick
        let settings = WidgetSettings.load(from: modules)
        launcherView.widgetSpots = settings.spots(
            WidgetPlacement.load(from: modules).arrangement, from: Widgets.ids,
            wide: Widgets.wide, tall: Widgets.tall)
        launcherView.widgetSizes = settings.sizes(from: Widgets.ids)
    }

    func launcherFrame(in visible: CGRect) -> CGRect {
        ScreenGeometry.centeredFrame(of: launcherSize, in: visible)
            .offsetBy(dx: 0, dy: -launcherView.widgetShift * Self.half)
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
        launcherView.onPage = { [weak self] page in
            guard let self else { return }
            widgets.page(page, in: launcherView)
        }
        widgets.onSearchedChange = { [weak self] in self?.searchAgain() }
        connectWidgetEditing()
    }

    private func connectWidgetEditing() {
        launcherView.widgetCatalogue = Widgets.gallery
        launcherView.onWidgetEdit = { [weak self] edit in
            guard let self else { return }
            widgetUndo = WidgetSnapshot(of: modules)
            Widgets.edit(edit, in: modules)
            widgetsChanged()
        }
        launcherView.onUndoWidgetEdit = { [weak self] in
            guard let self, let undo = widgetUndo else { return }
            widgetUndo = nil
            undo.restore(to: modules)
            widgetsChanged()
        }
        launcherView.onWidgetEditing = { [weak self] _ in self?.fitLauncher() }
    }

    func editWidgetsInLauncher() {
        guard modules?.isEnabled(Widgets.moduleID) != false else {
            NSSound.beep()
            return
        }
        hideLauncher()
        showLauncher()
        launcherView.editWidgets()
    }

    private func widgetsChanged() {
        arrangeWidgets()
        widgets.show(Widgets.added(in: modules), in: launcherView)
    }

    func showGlances() {
        let enabled = modules?.isEnabled(Widgets.moduleID) != false
        widgets.shown = enabled ? Widgets.added(in: modules) : []
        widgets.city = WeatherSettings.load(from: modules).city
        widgets.calendars.isOn = CalendarAgenda.isOn(in: modules)
        widgets.calendars.searchesDays = CalendarDayClick.searches(in: modules)
        widgets.calendars.searchesDays = CalendarDayClick.searches(in: modules)
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
