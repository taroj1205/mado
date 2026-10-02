import CoreGraphics
import Testing

@testable import WindowKit

@MainActor
@Suite struct WindowFollowerTests {
    struct Call {
        let frame: CGRect
        let previous: CGRect
        let time: ContinuousClock.Instant
    }

    final class SlowWindow {
        var calls: [Call] = []
        var refuses = false

        func apply(_ frame: CGRect, _ previous: CGRect) async -> Bool {
            calls.append(Call(frame: frame, previous: previous, time: .now))
            try? await Task.sleep(for: .milliseconds(30))
            return !refuses
        }
    }

    static let start = CGRect(x: 0, y: 0, width: 400, height: 300)

    static func frame(_ step: Int) -> CGRect {
        start.offsetBy(dx: CGFloat(step), dy: 0)
    }

    @Test func aSlowWindowGetsOnlyTheLatestFrameAfterTheOneInFlight() async throws {
        let window = SlowWindow()
        let follower = WindowFollower(from: Self.start, apply: window.apply)
        follower.send(Self.frame(1), throttled: false)
        try await Task.sleep(for: .milliseconds(5))
        try #require(window.calls.count == 1)
        for step in 2...100 {
            follower.send(Self.frame(step), throttled: false)
        }
        await follower.finish()
        #expect(window.calls.map(\.frame) == [Self.frame(1), Self.frame(100)])
        #expect(window.calls.map(\.previous) == [Self.start, Self.frame(1)])
    }

    @Test func resizesWaitTheIntervalBetweenUpdatesButMovesDoNot() async throws {
        let interval = Duration.milliseconds(400)
        let window = SlowWindow()
        let follower = WindowFollower(from: Self.start, interval: interval, apply: window.apply)
        follower.send(Self.frame(1), throttled: true)
        try await Task.sleep(for: .milliseconds(20))
        follower.send(Self.frame(2), throttled: true)
        await follower.finish()
        try #require(window.calls.count == 2)
        #expect(window.calls[1].time - window.calls[0].time >= interval)

        follower.send(Self.frame(3), throttled: false)
        try await Task.sleep(for: .milliseconds(20))
        follower.send(Self.frame(4), throttled: false)
        await follower.finish()
        try #require(window.calls.count == 4)
        #expect(window.calls[3].time - window.calls[2].time < interval)
    }

    @Test func aRefusedUpdateStopsFurtherUpdates() async {
        let window = SlowWindow()
        window.refuses = true
        let follower = WindowFollower(from: Self.start, apply: window.apply)
        follower.send(Self.frame(1), throttled: false)
        await follower.finish()
        follower.send(Self.frame(2), throttled: false)
        await follower.finish()
        #expect(window.calls.map(\.frame) == [Self.frame(1)])
    }
}
