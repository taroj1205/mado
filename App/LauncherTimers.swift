import AppCore
import Foundation
import GlassUI

enum LauncherTimers {
    private static let symbol = "timer"
    private static let prefix = "timer."
    private static let startPrefix = "timer.start."
    private static let stopwatchID = "timer.stopwatch"
    private static let pomodoroID = "timer.pomodoro"
    private static let secondsPerMinute = 60.0
    private static let shortPreset = 5.0
    private static let mediumPreset = 10.0
    private static let longPreset = 25.0

    private static var presets: [TimeInterval] {
        [shortPreset, mediumPreset, longPreset].map { $0 * secondsPerMinute }
    }

    static func owns(_ id: String) -> Bool {
        id.hasPrefix(prefix)
    }

    static func sections(for query: String) -> [ResultList.Section] {
        guard let parsed = TimerQuery(query) else { return [] }
        var items =
            switch parsed {
            case let .timer(length, name):
                (length.map { [$0] } ?? presets).map { start($0, named: name) }

            case .stopwatch:
                [row(id: stopwatchID, title: "Start Stopwatch", detail: "Counts up from 0:00")]

            case let .pomodoro(label):
                [
                    row(
                        id: pomodoroID, title: "Start Pomodoro",
                        detail: ["Focus \(TimerClock.length(Pomodoro.Phase.focus.length))", label]
                            .filter { !$0.isEmpty }.joined(separator: " · "))
                ]
            }
        items[0].prefersSelection = true
        return [ResultList.Section(title: "Timer", items: items)]
    }

    @MainActor
    static func action(for id: String, query: String, on item: MenuBarTimerItem) -> CommandAction? {
        guard let parsed = TimerQuery(query) else { return nil }
        switch parsed {
        case let .timer(_, name):
            guard id.hasPrefix(startPrefix), let seconds = Double(id.dropFirst(startPrefix.count))
            else { return nil }
            return CommandAction(id: "start", title: "Start Timer") {
                item.startTimer(seconds, named: name)
            }

        case .stopwatch:
            return CommandAction(id: "start", title: "Start Stopwatch") { item.startStopwatch() }

        case let .pomodoro(label):
            return CommandAction(id: "start", title: "Start Pomodoro") { item.startPomodoro(label) }
        }
    }

    private static func start(_ length: TimeInterval, named name: String) -> ResultList.Item {
        row(
            id: "\(startPrefix)\(Int(length))", title: "Start Timer",
            detail: [TimerClock.length(length), name].filter { !$0.isEmpty }.joined(
                separator: " · "))
    }

    private static func row(id: String, title: String, detail: String) -> ResultList.Item {
        ResultList.Item(
            id: id, title: title, subtitle: detail, kind: "", symbol: symbol, action: "Start")
    }
}
