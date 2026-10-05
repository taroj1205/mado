@MainActor
protocol SettingsSidebarDelegate: AnyObject {
    func sidebar(picked page: Int)
    func sidebar(preview target: SettingsSidebar.Target?, matches: [String: [Int]])
    func sidebar(go target: SettingsSidebar.Target, matches: [String: [Int]])
    func sidebarEndedSearch()
}
