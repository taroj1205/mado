import Foundation
import Testing

@testable import AppCore

@Suite struct TimerPanelTests {
    private static let minute: TimeInterval = 60
    private let calendar: Calendar
    private let start: Date

    init() throws {
        var auckland = Calendar(identifier: .gregorian)
        auckland.timeZone = try #require(TimeZone(identifier: "Pacific/Auckland"))
        auckland.locale = Locale(identifier: "en_GB")
        calendar = auckland
        start =
            auckland.startOfDay(for: Date(timeIntervalSince1970: 1_790_000_000)) + 9 * 3_600
            + 41 * Self.minute
    }

    private func panel(_ timers: Timers, after offset: TimeInterval = 0) -> TimerPanel {
        TimerPanel(timers, at: start + offset, calendar: calendar)
    }

    @Test func aRunningPomodoroShowsTheFocusRoundAndWhenTheBreakStarts() {
        var timers = Timers()
        timers.add(41 * Self.minute + 10, named: "Laundry", at: start)
        timers.add(3 * Self.minute, named: "Tea", at: start)
        timers.startPomodoro("Widgets UI", at: start)
        let shown = panel(timers, after: 6 * Self.minute + 18)
        #expect(shown.caption == "POMODORO · FOCUS 1 OF 4")
        #expect(shown.title == "Focus — Widgets UI")
        #expect(shown.clock == "18:42")
        #expect(shown.detail == "Break at 10:06")
        #expect(shown.buttons.map(\.title) == ["Pause", "+5 min", "Stop"])
        #expect(shown.buttons.first?.isPrimary == true)
        #expect(shown.rows.map(\.name) == ["Laundry", "Tea"])
        #expect(abs(shown.fraction - 0.748) < 0.001)
    }

    @Test func theTimerTabListsTheOtherTimersBesideTheFeaturedOne() {
        var timers = Timers()
        timers.add(41 * Self.minute + 10, named: "Laundry", at: start)
        timers.add(3 * Self.minute, named: "Tea", at: start)
        var shown = panel(timers)
        #expect(shown.title == "Tea")
        #expect(shown.rows == [.init(id: timers.countdowns[0].id, name: "Laundry", time: "41:10")])
        timers.perform(.toggle, at: start)
        shown = panel(timers, after: 30)
        #expect(shown.detail == "Paused")
        #expect(shown.buttons.first?.title == "Resume")
        timers.select(timers.countdowns[0].id)
        shown = panel(timers, after: 30)
        #expect(shown.title == "Laundry")
        #expect(shown.rows.map(\.time) == ["3:00 · paused"])
    }

    @Test func aFinishedTimerOffersRestartAndAnEmptyTabOffersPresets() {
        var timers = Timers()
        #expect(panel(timers).buttons.map(\.title) == ["5 min", "10 min", "25 min"])
        timers.add(Self.minute, named: "Egg", at: start)
        _ = timers.tick(at: start + 2 * Self.minute)
        let shown = panel(timers, after: 2 * Self.minute)
        #expect(shown.state == .done)
        #expect(shown.detail == "Done")
        #expect(shown.buttons.first?.title == "Restart")
    }

    @Test func theStopwatchTabOffersStartThenPauseAndReset() {
        var timers = Timers()
        timers.mode = .stopwatch
        #expect(panel(timers).buttons.map(\.title) == ["Start"])
        timers.perform(.toggle, at: start)
        let shown = panel(timers, after: 75)
        #expect(shown.clock == "1:15")
        #expect(shown.buttons.map(\.title) == ["Pause", "Reset"])
        timers.perform(.reset, at: start + 80)
        #expect(panel(timers).clock == "0:00")
    }

    @Test func buttonsActOnTheTabThatIsShown() {
        var timers = Timers()
        timers.perform(.startTimer(25 * Self.minute), at: start)
        timers.perform(.addFive, at: start)
        #expect(timers.countdowns.first?.remaining(at: start) == 30 * Self.minute)
        timers.perform(.toggle, at: start)
        #expect(timers.countdowns.first?.isRunning(at: start) == false)
        timers.perform(.stop, at: start)
        #expect(timers.countdowns.isEmpty)

        timers.mode = .pomodoro
        timers.perform(.startPomodoro, at: start)
        timers.perform(.addFive, at: start)
        #expect(timers.pomodoro?.countdown.remaining(at: start) == 30 * Self.minute)
        timers.perform(.stop, at: start)
        #expect(timers.pomodoro == nil)
        #expect(panel(timers).buttons.map(\.title) == ["Start"])
    }
}
