import AppKit
import ApplicationServices
import GlassUI
import WindowKit

extension LyricsPin {
    var isBeside: Bool {
        self == .dock || self == .menus
    }

    var barLook: LyricsBar.Look {
        self == .dock ? .type : .pill
    }
}

extension LyricsStage {
    private static let surveySeconds = 1

    func showBar(_ verse: WidgetGrid.Verse, pin: LyricsPin, on screen: NSScreen) -> Bool {
        guard pin.isBeside else {
            bar.hide(animated: false)
            return false
        }
        guard surroundings != nil else {
            float.hide(animated: false)
            return true
        }
        guard let spot = spot(for: pin, on: screen) else {
            bar.hide(animated: false)
            return false
        }
        float.hide(animated: false)
        bar.show(verse, look: pin.barLook, in: spot, hidesInSharing: settings.hidesInSharing)
        return true
    }

    private func spot(for pin: LyricsPin, on screen: NSScreen) -> NSRect? {
        surroundings.flatMap { around in
            LyricsBarSpot.frame(
                for: pin, around: around, side: settings.dockSide,
                on: LyricsBarSpot.Screen(
                    frame: screen.frame, visibleFrame: screen.visibleFrame,
                    notchEdge: screen.auxiliaryTopLeftArea?.maxX))
        }
    }

    func syncSurvey() {
        guard settings.isActive, settings.pin?.isBeside == true else {
            survey?.cancel()
            survey = nil
            surroundings = nil
            return
        }
        guard survey == nil else { return }
        survey = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await measure()
                try? await Task.sleep(for: .seconds(Self.surveySeconds))
            }
        }
    }

    private func measure() async {
        let screens = NSScreen.screens
        let primary = screens.first?.frame ?? .zero
        let appKit = { (quartz: CGRect) in
            ScreenGeometry.appKitRect(fromQuartz: quartz, primary: primary)
        }
        let dock = await SystemBars.dock().map(appKit)
        let frontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let menusEnd =
            if let frontmost, frontmost != getpid() {
                await SystemBars.menus(of: frontmost).map(appKit).flatMap { menus in
                    screens.first { $0.frame.intersects(menus) }
                        .map { screen in menus.maxX - screen.frame.minX }
                }
            } else {
                surroundings?.menusEnd
            }
        let excluded = bar.windowNumber
        let items = await Task.detached { SystemBars.statusItems(excluding: excluded) }.value
            .map(appKit)
        let next = LyricsSurroundings(dock: dock, menusEnd: menusEnd, statusItems: items)
        guard settings.pin?.isBeside == true, next != surroundings else { return }
        surroundings = next
        update()
    }
}
