public import Foundation

public struct Timers: Codable, Equatable, Sendable {
    public enum Mode: String, Codable, CaseIterable, Sendable {
        case timer = "countdown"
        case stopwatch = "stopwatch"
        case pomodoro = "pomodoro"
    }

    public enum State: Sendable {
        case running
        case paused
        case done
    }

    public enum Event: Equatable, Sendable {
        case timerFinished(String)
        case phaseStarted(Pomodoro.Phase)
        case pomodoroFinished
    }

    public struct Headline: Equatable, Sendable {
        public let mode: Mode
        public let state: State
        public let text: String
    }

    public static let defaultName = "Timer"

    public var mode: Mode
    public private(set) var countdowns: [Countdown] = []
    public private(set) var stopwatch = Stopwatch()
    public private(set) var pomodoro: Pomodoro?
    public private(set) var pinned: Countdown.ID?

    public var isActive: Bool {
        !countdowns.isEmpty || !stopwatch.isIdle || pomodoro != nil
    }

    public init() {
        mode = .timer
    }

    public func isTicking(at now: Date) -> Bool {
        stopwatch.isRunning || pomodoro?.countdown.endsAt != nil
            || countdowns.contains { $0.isRunning(at: now) }
    }

    public func featured(at now: Date) -> Countdown? {
        if let shown = countdowns.first(where: { $0.id == pinned }) { return shown }
        let running = countdowns.filter { $0.isRunning(at: now) }
        return running.min { $0.remaining(at: now) < $1.remaining(at: now) } ?? countdowns.first
    }

    public mutating func add(_ length: TimeInterval, named name: String, at now: Date) {
        countdowns.append(Countdown(name: name, length: length, startingAt: now))
        mode = .timer
    }

    public mutating func toggle(_ id: Countdown.ID, at now: Date) {
        update(id) { timer in
            if timer.isFinished(at: now) {
                timer.restart(at: now)
            } else if timer.isRunning(at: now) {
                timer.pause(at: now)
            } else {
                timer.resume(at: now)
            }
        }
    }

    public mutating func extend(_ id: Countdown.ID, by extra: TimeInterval, at now: Date) {
        update(id) { $0.extend(by: extra, at: now) }
    }

    public mutating func remove(_ id: Countdown.ID) {
        countdowns.removeAll { $0.id == id }
        if pinned == id { pinned = nil }
    }

    public mutating func select(_ id: Countdown.ID) {
        pin(id)
        mode = .timer
    }

    mutating func pin(_ id: Countdown.ID) {
        pinned = id
    }

    public mutating func startStopwatch(at now: Date) {
        stopwatch.start(at: now)
        mode = .stopwatch
    }

    public mutating func toggleStopwatch(at now: Date) {
        if stopwatch.isRunning {
            stopwatch.pause(at: now)
        } else {
            stopwatch.start(at: now)
        }
        mode = .stopwatch
    }

    public mutating func resetStopwatch() {
        stopwatch.reset()
    }

    public mutating func startPomodoro(_ label: String, at now: Date) {
        pomodoro = Pomodoro(label: label, at: now)
        mode = .pomodoro
    }

    public mutating func togglePomodoro(at now: Date) {
        guard var current = pomodoro else { return }
        if current.countdown.endsAt == nil {
            current.resume(at: now)
        } else {
            current.pause(at: now)
        }
        pomodoro = current
    }

    public mutating func extendPomodoro(by extra: TimeInterval, at now: Date) {
        pomodoro?.extend(by: extra, at: now)
    }

    public mutating func stopPomodoro() {
        pomodoro = nil
    }

    public func isPomodoroInProgress(at now: Date) -> Bool {
        pomodoro.map { !$0.isFinished(at: now) } ?? false
    }

    public mutating func showFinishedPomodoro(at now: Date) {
        guard pomodoro?.isFinished(at: now) == true,
            !countdowns.contains(where: { $0.isFinished(at: now) })
        else { return }
        mode = .pomodoro
    }

    public mutating func dismissFinished(at now: Date) {
        countdowns.removeAll { $0.isFinished(at: now) && $0.isAnnounced }
        if !countdowns.contains(where: { $0.id == pinned }) { pinned = nil }
        guard mode == .pomodoro, let current = pomodoro, current.isFinished(at: now),
            current.countdown.isAnnounced
        else { return }
        pomodoro = nil
    }

    public mutating func tick(at now: Date) -> [Event] {
        var events: [Event] = []
        for index in countdowns.indices where countdowns[index].settle(at: now) {
            events.append(.timerFinished(countdowns[index].name))
        }
        switch pomodoro?.advance(at: now) {
        case .entered(let phase): events.append(.phaseStarted(phase))

        case .finished: events.append(.pomodoroFinished)

        case .unchanged, nil: break
        }
        return events
    }

    public func headline(at now: Date) -> Headline? {
        if countdowns.contains(where: { $0.isFinished(at: now) }) {
            return Headline(mode: .timer, state: .done, text: "Done")
        }
        if pomodoro?.isFinished(at: now) == true {
            return Headline(mode: .pomodoro, state: .done, text: "Done")
        }
        let timers = countdowns.sorted { $0.remaining(at: now) < $1.remaining(at: now) }
        let clocks = (pomodoro.map { [$0.countdown] } ?? []) + timers
        if let running = clocks.first(where: { $0.isRunning(at: now) }) {
            return countdownHeadline(running, .running, at: now)
        }
        if stopwatch.isRunning { return stopwatchHeadline(.running, at: now) }
        if let paused = clocks.first { return countdownHeadline(paused, .paused, at: now) }
        return stopwatch.isIdle ? nil : stopwatchHeadline(.paused, at: now)
    }

    private func countdownHeadline(_ timer: Countdown, _ state: State, at now: Date) -> Headline {
        Headline(
            mode: timer.id == pomodoro?.countdown.id ? .pomodoro : .timer, state: state,
            text: TimerClock.text(timer.remaining(at: now), roundingUp: true))
    }

    private func stopwatchHeadline(_ state: State, at now: Date) -> Headline {
        Headline(
            mode: .stopwatch, state: state,
            text: TimerClock.text(stopwatch.elapsed(at: now), roundingUp: false))
    }

    private mutating func update(_ id: Countdown.ID, _ change: (inout Countdown) -> Void) {
        guard let index = countdowns.firstIndex(where: { $0.id == id }) else { return }
        change(&countdowns[index])
    }
}
