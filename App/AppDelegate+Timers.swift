import AppCore
import AppKit
import GlassUI

extension AppDelegate {
    private static let timerQuery = "timer "

    func timerSections(for query: String) -> [ResultList.Section] {
        guard menuBar.timer.isOn else { return [] }
        return LauncherTimers.sections(
            for: query, pomodoroInProgress: menuBar.timer.timers.isPomodoroInProgress(at: .now))
    }

    func timerActions(for item: ResultList.Item) -> [(action: CommandAction, keys: [String])] {
        let query = launcherView.field.stringValue
        guard let action = LauncherTimers.action(for: item.id, query: query, on: menuBar.timer)
        else { return [] }
        return [(action, LauncherView.Action.primaryKeys)]
    }

    func openTimerSearch() {
        showLauncher()
        launcherView.field.stringValue = Self.timerQuery
        launcherView.field.currentEditor()?.selectedRange = NSRange(
            location: Self.timerQuery.utf16.count, length: 0)
        searchAgain()
    }
}
