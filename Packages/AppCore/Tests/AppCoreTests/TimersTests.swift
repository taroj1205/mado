import Foundation
import Testing

@testable import AppCore

@Suite struct TimersTests {
    private static let minute: TimeInterval = 60
    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    private func at(_ offset: TimeInterval) -> Date {
        start + offset
    }

    @Test func aTimerCountsDownAndFinishesOnce() {
        var timers = Timers()
        timers.add(3 * Self.minute, named: "Tea", at: start)
        #expect(timers.headline(at: at(0)) == .init(state: .running, text: "3:00"))
        #expect(timers.headline(at: at(0.4)) == .init(state: .running, text: "3:00"))
        #expect(timers.headline(at: at(1)) == .init(state: .running, text: "2:59"))
        #expect(timers.tick(at: at(179)).isEmpty)
        #expect(timers.tick(at: at(180)) == [.timerFinished("Tea")])
        #expect(timers.tick(at: at(181)).isEmpty)
        #expect(timers.headline(at: at(181)) == .init(state: .done, text: "Done"))
        #expect(!timers.isTicking(at: at(181)))
    }

    @Test func pausingKeepsTheTimeLeftAndResumingRunsIt() throws {
        var timers = Timers()
        timers.add(10 * Self.minute, named: "Laundry", at: start)
        let id = try #require(timers.countdowns.first?.id)
        timers.toggle(id, at: at(90))
        #expect(timers.headline(at: at(500)) == .init(state: .paused, text: "8:30"))
        #expect(!timers.isTicking(at: at(500)))
        timers.toggle(id, at: at(500))
        #expect(timers.headline(at: at(560)) == .init(state: .running, text: "7:30"))
    }

    @Test func fiveMoreMinutesExtendsRunningPausedAndFinishedTimers() throws {
        var timers = Timers()
        timers.add(Self.minute, named: "Egg", at: start)
        let id = try #require(timers.countdowns.first?.id)
        timers.extend(id, by: 5 * Self.minute, at: at(30))
        #expect(timers.countdowns.first?.remaining(at: at(30)) == 5.5 * Self.minute)
        timers.toggle(id, at: at(30))
        timers.extend(id, by: 5 * Self.minute, at: at(60))
        #expect(timers.countdowns.first?.remaining(at: at(60)) == 10.5 * Self.minute)
        timers.toggle(id, at: at(60))
        _ = timers.tick(at: at(60 + 11 * Self.minute))
        timers.extend(id, by: 5 * Self.minute, at: at(1_000))
        #expect(timers.countdowns.first?.remaining(at: at(1_000)) == 5 * Self.minute)
        #expect(timers.countdowns.first?.isRunning(at: at(1_000)) == true)
    }

    @Test func aFinishedTimerRestartsFromItsLength() throws {
        var timers = Timers()
        timers.add(Self.minute, named: "Egg", at: start)
        _ = timers.tick(at: at(90))
        let id = try #require(timers.countdowns.first?.id)
        timers.toggle(id, at: at(100))
        #expect(timers.countdowns.first?.remaining(at: at(100)) == Self.minute)
        #expect(timers.tick(at: at(161)) == [.timerFinished("Egg")])
    }

    @Test func theStopwatchCountsUpAndResets() {
        var timers = Timers()
        timers.toggleStopwatch(at: start)
        #expect(timers.headline(at: at(75.9)) == .init(state: .running, text: "1:15"))
        timers.toggleStopwatch(at: at(100))
        #expect(timers.headline(at: at(900)) == .init(state: .paused, text: "1:40"))
        timers.toggleStopwatch(at: at(900))
        #expect(timers.stopwatch.elapsed(at: at(960)) == 160)
        timers.resetStopwatch()
        #expect(timers.stopwatch.isIdle)
        #expect(!timers.isActive)
        #expect(timers.headline(at: at(1_000)) == nil)
    }

    @Test func aPomodoroWalksFocusAndBreaksThenFinishes() {
        var timers = Timers()
        timers.startPomodoro("Widgets UI", at: start)
        #expect(timers.pomodoro?.title == "Focus — Widgets UI")
        #expect(timers.pomodoro?.caption == "Focus 1 of 4")
        #expect(timers.tick(at: at(24 * Self.minute)).isEmpty)
        #expect(timers.tick(at: at(25 * Self.minute)) == [.phaseStarted(.shortBreak)])
        #expect(timers.pomodoro?.title == "Break")
        #expect(timers.pomodoro?.next == .focus)
        #expect(timers.tick(at: at(30 * Self.minute)) == [.phaseStarted(.focus)])
        #expect(timers.pomodoro?.caption == "Focus 2 of 4")
        #expect(timers.headline(at: at(31 * Self.minute))?.text == "24:00")

        var last = Pomodoro(label: "", at: start)
        #expect(last.advance(at: at(115 * Self.minute)) == .entered(.longBreak))
        #expect(last.caption == "Long break")
        #expect(last.next == nil)
        #expect(last.advance(at: at(129 * Self.minute)) == .unchanged)
        #expect(last.advance(at: at(130 * Self.minute)) == .finished)
    }

    @Test func aPomodoroCatchesUpAfterTheMacWasAsleep() {
        var pomodoro = Pomodoro(label: "", at: start)
        #expect(pomodoro.advance(at: at(62 * Self.minute)) == .entered(.focus))
        #expect(pomodoro.round == 3)
        #expect(pomodoro.countdown.remaining(at: at(62 * Self.minute)) == 23 * Self.minute)
    }

    @Test func aPausedPomodoroDoesNotAdvance() {
        var timers = Timers()
        timers.startPomodoro("", at: start)
        timers.togglePomodoro(at: at(10 * Self.minute))
        #expect(timers.tick(at: at(3 * 3_600)).isEmpty)
        #expect(timers.pomodoro?.countdown.remaining(at: at(3 * 3_600)) == 15 * Self.minute)
        timers.togglePomodoro(at: at(3 * 3_600))
        timers.extendPomodoro(by: 5 * Self.minute, at: at(3 * 3_600))
        #expect(timers.pomodoro?.countdown.remaining(at: at(3 * 3_600)) == 20 * Self.minute)
    }

    @Test func theBarShowsThePomodoroThenTheSoonestTimerThenTheStopwatch() {
        var timers = Timers()
        timers.toggleStopwatch(at: start)
        #expect(timers.headline(at: at(10))?.text == "0:10")
        timers.add(20 * Self.minute, named: "Laundry", at: start)
        timers.add(5 * Self.minute, named: "Tea", at: start)
        #expect(timers.headline(at: at(10))?.text == "4:50")
        timers.startPomodoro("", at: start)
        #expect(timers.headline(at: at(10))?.text == "24:50")
        #expect(timers.featured(at: at(10))?.name == "Tea")
    }

    @Test func aPickedTimerStaysFeaturedUntilItIsRemoved() throws {
        var timers = Timers()
        timers.add(20 * Self.minute, named: "Laundry", at: start)
        timers.add(5 * Self.minute, named: "Tea", at: start)
        let laundry = try #require(timers.countdowns.first?.id)
        timers.mode = .pomodoro
        timers.select(laundry)
        #expect(timers.mode == .timer)
        #expect(timers.featured(at: at(10))?.name == "Laundry")
        timers.remove(laundry)
        #expect(timers.featured(at: at(10))?.name == "Tea")
    }

    @Test func startingARunningStopwatchKeepsItRunning() {
        var timers = Timers()
        timers.startStopwatch(at: start)
        timers.startStopwatch(at: at(30))
        #expect(timers.stopwatch.elapsed(at: at(60)) == 60)
    }

    @Test func stateSurvivesAnEncodeAndDecode() throws {
        var timers = Timers()
        timers.add(Self.minute, named: "Tea", at: start)
        timers.startPomodoro("Work", at: start)
        timers.toggleStopwatch(at: start)
        let decoded = try JSONDecoder().decode(Timers.self, from: JSONEncoder().encode(timers))
        #expect(decoded == timers)
    }

    @Test func clocksReadAsMinutesSecondsAndHours() {
        #expect(TimerClock.text(0, roundingUp: true) == "0:00")
        #expect(TimerClock.text(9.2, roundingUp: true) == "0:10")
        #expect(TimerClock.text(3_725, roundingUp: false) == "1:02:05")
        #expect(TimerClock.length(25 * Self.minute) == "25 min")
        #expect(TimerClock.length(90 * Self.minute) == "1 h 30 min")
        #expect(TimerClock.length(2 * 3_600) == "2 h")
        #expect(TimerClock.length(45) == "45 s")
    }
}
