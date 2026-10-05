import Testing

@testable import AppCore

@Suite struct TimerQueryTests {
    @Test func aTimerTakesALengthAndAName() {
        #expect(TimerQuery("timer 25m") == .timer(length: 1_500, name: ""))
        #expect(TimerQuery("Timer 25") == .timer(length: 1_500, name: ""))
        #expect(TimerQuery("timer 25 min") == .timer(length: 1_500, name: ""))
        #expect(TimerQuery("timer 1h30m") == .timer(length: 5_400, name: ""))
        #expect(TimerQuery("timer 1h 30m") == .timer(length: 5_400, name: ""))
        #expect(TimerQuery("timer 90s tea") == .timer(length: 90, name: "tea"))
        #expect(TimerQuery("timer pasta 12 minutes") == .timer(length: 720, name: "pasta"))
        #expect(TimerQuery("timer 1.5h") == .timer(length: 5_400, name: ""))
        #expect(TimerQuery("timer 0.6s") == .timer(length: 1, name: ""))
        #expect(TimerQuery("timer 0.4s") == nil)
    }

    @Test func aTimerWithoutAUsableLengthHasNone() {
        #expect(TimerQuery("timer") == .timer(length: nil, name: ""))
        #expect(TimerQuery("timer tea") == .timer(length: nil, name: "tea"))
        #expect(TimerQuery("timer 5x") == .timer(length: nil, name: "5x"))
    }

    @Test func aSuppliedLengthThatCannotRunIsNotATimer() {
        #expect(TimerQuery("timer 0m") == nil)
        #expect(TimerQuery("timer 101h") == nil)
        #expect(TimerQuery("timer tea 0") == nil)
    }

    @Test func theOtherKindsAreSpelledOut() {
        #expect(TimerQuery("stopwatch") == .stopwatch)
        #expect(TimerQuery("pomodoro") == .pomodoro(label: ""))
        #expect(TimerQuery("pomodoro Widgets UI") == .pomodoro(label: "Widgets UI"))
    }

    @Test func otherSearchesAreNotTimers() {
        #expect(TimerQuery("") == nil)
        #expect(TimerQuery("timers") == nil)
        #expect(TimerQuery("stopwatch fast") == nil)
        #expect(TimerQuery("safari") == nil)
        #expect(TimerQuery("25m timer") == nil)
    }
}
