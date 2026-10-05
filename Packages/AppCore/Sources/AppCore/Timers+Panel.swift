public import Foundation

extension Timers {
    public mutating func perform(_ action: TimerPanel.Action, at now: Date) {
        switch action {
        case .startTimer(let length): add(length, named: Self.defaultName, at: now)

        case .startPomodoro: startPomodoro("", at: now)

        default:
            switch mode {
            case .timer: performOnTimer(action, at: now)
            case .stopwatch: performOnStopwatch(action, at: now)
            case .pomodoro: performOnPomodoro(action, at: now)
            }
        }
    }

    private mutating func performOnTimer(_ action: TimerPanel.Action, at now: Date) {
        guard let id = featured(at: now)?.id else { return }
        pin(id)
        switch action {
        case .toggle: toggle(id, at: now)
        case .addFive: extend(id, by: TimerPanel.extra, at: now)
        case .stop: remove(id)
        default: break
        }
    }

    private mutating func performOnStopwatch(_ action: TimerPanel.Action, at now: Date) {
        switch action {
        case .toggle: toggleStopwatch(at: now)
        case .reset: resetStopwatch()
        default: break
        }
    }

    private mutating func performOnPomodoro(_ action: TimerPanel.Action, at now: Date) {
        switch action {
        case .toggle: togglePomodoro(at: now)
        case .addFive: extendPomodoro(by: TimerPanel.extra, at: now)
        case .stop: stopPomodoro()
        default: break
        }
    }
}
