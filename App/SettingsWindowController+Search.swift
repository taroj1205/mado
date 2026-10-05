import AppKit
import SearchKit

extension SettingsWindowController: SettingsSidebarDelegate {
    struct Home {
        let page: Int
        let tab: String?
        let scroll: NSPoint
    }

    func sidebar(picked page: Int) {
        tabs.selectedTabViewItemIndex = page
    }

    func sidebar(preview target: SettingsSidebar.Target?, matches: [String: [Int]]) {
        guard let target else {
            restoreHome()
            return
        }
        if home == nil {
            let index = tabs.selectedTabViewItemIndex
            let page = page(at: index)
            home = Home(page: index, tab: page?.tabTitle, scroll: page?.scrollOrigin ?? .zero)
        }
        show(target, matches: matches, dimsOthers: target.entry != nil)
    }

    func sidebar(go target: SettingsSidebar.Target, matches: [String: [Int]]) {
        home = nil
        show(target, matches: matches, dimsOthers: false)
        if let entry = target.entry {
            spotlit?.spotlight.land(on: entry, choice: target.choice)
        }
    }

    func sidebarShowedPages() {
        restoreHome()
        spotlit?.spotlight.focus = nil
        spotlit = nil
    }

    func sidebarEndedSearch() {
        sidebarShowedPages()
        sidebar.select(page: tabs.selectedTabViewItemIndex)
        sidebar.endSearch()
    }

    func endSearchIfActive() -> Bool {
        guard sidebar.searching || spotlit != nil else { return false }
        sidebarEndedSearch()
        return true
    }

    @objc
    func focusSearch(_: Any?) {
        sidebar.focusField()
    }

    func endSearchOnTabPicks() {
        for index in tabs.tabViewItems.indices {
            page(at: index)?.onPickTab = { [weak self] in
                self?.home = nil
                _ = self?.endSearchIfActive()
            }
        }
    }

    private func page(at index: Int) -> SettingsPageController? {
        tabs.tabViewItems[index].viewController as? SettingsPageController
    }

    private func show(
        _ target: SettingsSidebar.Target, matches: [String: [Int]], dimsOthers: Bool
    ) {
        guard let index = SettingsPage.all.firstIndex(where: { $0.title == target.place.page })
        else { return }
        tabs.selectedTabViewItemIndex = index
        guard let page = page(at: index) else { return }
        if spotlit !== page {
            spotlit?.spotlight.focus = nil
        }
        page.show(tab: target.place.tab)
        page.spotlight.focus = .init(
            matches: matches, selected: target.entry, dimsOthers: dimsOthers)
        spotlit = page
    }

    private func restoreHome() {
        guard let home else { return }
        self.home = nil
        spotlit?.spotlight.focus = nil
        spotlit = nil
        tabs.selectedTabViewItemIndex = home.page
        let page = page(at: home.page)
        page?.show(tab: home.tab)
        page?.scrollOrigin = home.scroll
    }
}
