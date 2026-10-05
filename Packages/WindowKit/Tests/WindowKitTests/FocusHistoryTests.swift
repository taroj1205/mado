import CoreGraphics
import Testing

@testable import WindowKit

@Suite struct FocusHistoryTests {
    private static func windows(_ numbers: [CGWindowID?]) -> [WindowList.Window] {
        numbers.enumerated().map { id, number in
            WindowList.Window(id: id, pid: 1, title: "", number: number)
        }
    }

    private static func order(
        _ history: inout FocusHistory, _ numbers: [CGWindowID?]
    ) -> [CGWindowID?] {
        history.ordered(windows(numbers)).map(\.number)
    }

    @Test func putsTheLastFocusedWindowsFirstAndTheRestInTheirStackingOrder() {
        var history = FocusHistory()
        history.focused(30)
        history.focused(10)
        #expect(Self.order(&history, [20, 30, 40, 10]) == [10, 30, 20, 40])
    }

    @Test func focusingAWindowAgainMovesItToTheFront() {
        var history = FocusHistory()
        for number: CGWindowID in [10, 20, 10] {
            history.focused(number)
        }
        #expect(Self.order(&history, [20, 10]) == [10, 20])
    }

    @Test func keepsWindowsWithoutANumberAfterTheFocusedOnes() {
        var history = FocusHistory()
        history.focused(20)
        #expect(Self.order(&history, [nil, 10, 20]) == [20, nil, 10])
    }

    @Test func forgetsWindowsThatAreNoLongerListed() {
        var history = FocusHistory()
        history.focused(10)
        history.focused(20)
        _ = Self.order(&history, [10])
        #expect(Self.order(&history, [30, 20, 10]) == [10, 30, 20])
    }
}
