public import Foundation

public struct TimerPanel: Equatable, Sendable {
    public enum Action: Equatable, Sendable {
        case toggle
        case addFive
        case stop
        case reset
        case startTimer(TimeInterval)
        case startPomodoro
    }

    public struct Button: Equatable, Sendable {
        public let title: String
        public let action: Action
        public let isPrimary: Bool
    }

    public struct Row: Equatable, Sendable, Identifiable {
        public let id: Countdown.ID
        public let name: String
        public let time: String
    }

    private struct Face {
        var caption: String
        var title: String
        var detail: String
        var clock: String
        var fraction: Double
        var state: Timers.State
        var buttons: [Button]
    }

    private static let secondsPerMinute = 60.0
    private static let extraMinutes = 5.0
    private static let shortPreset = 5.0
    private static let mediumPreset = 10.0
    private static let longPreset = 25.0
    static let extra = extraMinutes * secondsPerMinute

    public let mode: Timers.Mode
    public let caption: String
    public let title: String
    public let detail: String
    public let clock: String
    public let fraction: Double
    public let state: Timers.State
    public let buttons: [Button]
    public let rows: [Row]

    public init(_ timers: Timers, at now: Date, calendar: Calendar) {
        let featured = timers.featured(at: now)
        let others = timers.countdowns.filter { $0.id != featured?.id || timers.mode != .timer }
        mode = timers.mode
        rows = others.map { Row(id: $0.id, name: $0.name, time: Self.time(of: $0, at: now)) }
        let face =
            switch timers.mode {
            case .timer: Self.face(of: featured, at: now, calendar: calendar)
            case .stopwatch: Self.face(of: timers.stopwatch, at: now)
            case .pomodoro: Self.face(of: timers.pomodoro, at: now, calendar: calendar)
            }
        caption = face.caption
        title = face.title
        detail = face.detail
        clock = face.clock
        fraction = face.fraction
        state = face.state
        buttons = face.buttons
    }

    private static func time(of countdown: Countdown, at now: Date) -> String {
        if countdown.isFinished(at: now) { return "Done" }
        let left = TimerClock.text(countdown.remaining(at: now), roundingUp: true)
        return countdown.isRunning(at: now) ? left : "\(left) · paused"
    }

    private static func clockTime(_ date: Date, calendar: Calendar) -> String {
        var style = Agenda.style(.init(date: .omitted, time: .shortened), in: calendar)
        style.locale = calendar.locale ?? .autoupdatingCurrent
        return date.formatted(style)
    }

    private static func controls(_ toggle: String) -> [Button] {
        [
            Button(title: toggle, action: .toggle, isPrimary: true),
            Button(title: "+5 min", action: .addFive, isPrimary: false),
            Button(title: "Stop", action: .stop, isPrimary: false),
        ]
    }

    private static func presets() -> [Button] {
        [shortPreset, mediumPreset, longPreset].map { minutes in
            let length = minutes * secondsPerMinute
            return Button(
                title: TimerClock.length(length), action: .startTimer(length), isPrimary: false)
        }
    }

    private static func face(of countdown: Countdown?, at now: Date, calendar: Calendar) -> Face {
        guard let countdown else {
            return Face(
                caption: "TIMER", title: "No timer yet", detail: "Start one, or type “timer 25m”",
                clock: TimerClock.text(0, roundingUp: true), fraction: 0, state: .paused,
                buttons: presets())
        }
        let remaining = countdown.remaining(at: now)
        let ends = clockTime(now + remaining, calendar: calendar)
        let (tone, toggle, note) =
            if countdown.isFinished(at: now) {
                (Timers.State.done, "Restart", "Done")
            } else if countdown.isRunning(at: now) {
                (Timers.State.running, "Pause", "Ends at \(ends)")
            } else {
                (Timers.State.paused, "Resume", "Paused")
            }
        return Face(
            caption: "TIMER", title: countdown.name, detail: note,
            clock: TimerClock.text(remaining, roundingUp: true),
            fraction: countdown.fraction(at: now), state: tone, buttons: controls(toggle))
    }

    private static func face(of stopwatch: Stopwatch, at now: Date) -> Face {
        let elapsed = stopwatch.elapsed(at: now)
        let (tone, toggle, note) =
            if stopwatch.isRunning {
                (Timers.State.running, "Pause", "Running")
            } else if stopwatch.isIdle {
                (Timers.State.paused, "Start", "Ready")
            } else {
                (Timers.State.paused, "Resume", "Paused")
            }
        var controls = [Button(title: toggle, action: .toggle, isPrimary: true)]
        if !stopwatch.isIdle {
            controls.append(Button(title: "Reset", action: .reset, isPrimary: false))
        }
        return Face(
            caption: "STOPWATCH", title: "Stopwatch", detail: note,
            clock: TimerClock.text(elapsed, roundingUp: false),
            fraction: elapsed.truncatingRemainder(dividingBy: secondsPerMinute) / secondsPerMinute,
            state: tone, buttons: controls)
    }

    private static func face(of pomodoro: Pomodoro?, at now: Date, calendar: Calendar) -> Face {
        guard let pomodoro else { return idleFace() }
        let phase = pomodoro.countdown
        let running = phase.isRunning(at: now)
        let ends = clockTime(now + phase.remaining(at: now), calendar: calendar)
        return Face(
            caption: "POMODORO · \(pomodoro.caption.uppercased())", title: pomodoro.title,
            detail: running ? "\(pomodoro.next?.title ?? "Done") at \(ends)" : "Paused",
            clock: TimerClock.text(phase.remaining(at: now), roundingUp: true),
            fraction: phase.fraction(at: now), state: running ? .running : .paused,
            buttons: controls(running ? "Pause" : "Resume"))
    }

    private static func idleFace() -> Face {
        let focus = TimerClock.length(Pomodoro.Phase.focus.length)
        let rest = TimerClock.length(Pomodoro.Phase.shortBreak.length)
        let long = TimerClock.length(Pomodoro.Phase.longBreak.length)
        return Face(
            caption: "POMODORO", title: "Focus \(focus) · break \(rest)",
            detail: "\(Pomodoro.rounds) rounds, then a \(long) break",
            clock: TimerClock.text(Pomodoro.Phase.focus.length, roundingUp: true), fraction: 0,
            state: .paused,
            buttons: [Button(title: "Start", action: .startPomodoro, isPrimary: true)])
    }
}
