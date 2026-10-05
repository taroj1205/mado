public import Foundation

public struct Pomodoro: Codable, Equatable, Sendable {
    public enum Phase: String, Codable, Sendable {
        case focus = "focus"
        case shortBreak = "short_break"
        case longBreak = "long_break"

        public var title: String {
            switch self {
            case .focus: "Focus"
            case .shortBreak: "Break"
            case .longBreak: "Long break"
            }
        }

        public var length: TimeInterval {
            switch self {
            case .focus: Pomodoro.focusMinutes * Pomodoro.minute
            case .shortBreak: Pomodoro.shortBreakMinutes * Pomodoro.minute
            case .longBreak: Pomodoro.longBreakMinutes * Pomodoro.minute
            }
        }
    }

    public enum Step: Equatable, Sendable {
        case unchanged
        case entered(Phase)
        case finished
    }

    public static let rounds = 4
    private static let minute: TimeInterval = 60
    private static let focusMinutes: TimeInterval = 25
    private static let shortBreakMinutes: TimeInterval = 5
    private static let longBreakMinutes: TimeInterval = 15

    public let label: String
    public private(set) var phase = Phase.focus
    public private(set) var round = 1
    public private(set) var countdown: Countdown

    public var title: String {
        phase == .focus && !label.isEmpty ? "\(phase.title) — \(label)" : phase.title
    }

    public var caption: String {
        phase == .focus ? "Focus \(round) of \(Self.rounds)" : phase.title
    }

    public var next: Phase? {
        successor?.phase
    }

    private var successor: (phase: Phase, round: Int)? {
        switch phase {
        case .focus: (round < Self.rounds ? .shortBreak : .longBreak, round)
        case .shortBreak: (.focus, round + 1)
        case .longBreak: nil
        }
    }

    public init(label: String, at now: Date) {
        self.label = label
        countdown = Countdown(name: label, length: Phase.focus.length, startingAt: now)
    }

    public mutating func advance(at now: Date) -> Step {
        var step = Step.unchanged
        while let end = countdown.endsAt, end <= now {
            guard let following = successor else { return .finished }
            (phase, round) = following
            countdown = Countdown(
                name: label, length: phase.length, startingAt: end, id: countdown.id)
            step = .entered(phase)
        }
        return step
    }

    public mutating func pause(at now: Date) {
        countdown.pause(at: now)
    }

    public mutating func resume(at now: Date) {
        countdown.resume(at: now)
    }

    public mutating func extend(by extra: TimeInterval, at now: Date) {
        countdown.extend(by: extra, at: now)
    }
}
