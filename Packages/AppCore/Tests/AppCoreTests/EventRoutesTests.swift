import CoreGraphics
import Testing

@testable import AppCore

@MainActor
@Suite struct EventRoutesTests {
    final class Calls {
        var names: [String] = []
    }

    @Test func eachRouteOnlySeesItsOwnTypes() throws {
        var routes = EventRoutes()
        let calls = Calls()
        _ = routes.add(types: [.flagsChanged]) { _, _ in
            calls.names.append("modifier")
            return false
        }
        _ = routes.add(types: [.keyDown, .keyUp]) { _, _ in
            calls.names.append("snippets")
            return false
        }
        let event = try #require(CGEvent(source: nil))

        #expect(!routes.dispatch(.keyDown, event))
        #expect(!routes.dispatch(.flagsChanged, event))
        #expect(!routes.dispatch(.leftMouseDown, event))
        #expect(calls.names == ["snippets", "modifier"])
    }

    @Test func theFirstRouteToSwallowEndsTheDispatch() throws {
        var routes = EventRoutes()
        let calls = Calls()
        _ = routes.add(types: [.keyDown]) { _, event in
            calls.names.append("radial")
            return event.getIntegerValueField(.keyboardEventKeycode) == 53
        }
        _ = routes.add(types: [.keyDown]) { _, _ in
            calls.names.append("enter guard")
            return false
        }
        let escape = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: true))
        let other = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true))

        #expect(routes.dispatch(.keyDown, escape))
        #expect(!routes.dispatch(.keyDown, other))
        #expect(calls.names == ["radial", "radial", "enter guard"])
    }

    @Test func observersSeeEventsAnEarlierRouteSwallowedAndNeverSwallow() throws {
        var routes = EventRoutes()
        let calls = Calls()
        _ = routes.add(types: [.keyDown]) { _, _ in
            calls.names.append("radial")
            return true
        }
        _ = routes.observe(types: [.keyDown, .keyUp]) { _, _ in
            calls.names.append("modifier tap")
        }
        _ = routes.add(types: [.keyDown]) { _, _ in
            calls.names.append("snippets")
            return false
        }
        let event = try #require(CGEvent(source: nil))

        #expect(routes.dispatch(.keyDown, event))
        #expect(!routes.dispatch(.keyUp, event))
        #expect(calls.names == ["radial", "modifier tap", "modifier tap"])
    }

    @Test func theMaskIsTheUnionOfTheRoutesStillAdded() {
        var routes = EventRoutes()
        let flags = routes.add(types: [.flagsChanged]) { _, _ in false }
        let keys = routes.add(types: [.keyDown, .flagsChanged]) { _, _ in false }
        let flagsBit = CGEventMask(1) << CGEventType.flagsChanged.rawValue
        let keyDownBit = CGEventMask(1) << CGEventType.keyDown.rawValue
        #expect(routes.mask == flagsBit | keyDownBit)

        routes.remove(keys)
        #expect(routes.mask == flagsBit)
        routes.remove(flags)
        #expect(routes.mask == 0)
    }

    @Test func dispatchingThroughFourRoutesStaysUnderOneMillisecond() throws {
        var routes = EventRoutes()
        var counts = [0, 0, 0, 0]
        let types: [[CGEventType]] = [
            [.flagsChanged, .leftMouseDown, .leftMouseUp, .keyDown, .keyUp],
            [.flagsChanged, .keyDown, .keyUp],
            [.keyDown],
            [.keyDown, .keyUp],
        ]
        for (index, routeTypes) in types.enumerated() {
            _ = routes.add(types: routeTypes) { _, event in
                counts[index] += Int(event.getIntegerValueField(.keyboardEventKeycode) & 1)
                return event.flags.contains(.maskSecondaryFn)
            }
        }
        let event = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 1, keyDown: true))
        let clock = ContinuousClock()
        var durations: [Duration] = []
        for _ in 0..<2_500 {
            for type in [CGEventType.flagsChanged, .keyDown, .keyUp, .leftMouseDown] {
                let start = clock.now
                _ = routes.dispatch(type, event)
                durations.append(clock.now - start)
            }
        }

        let p99 = durations.sorted()[durations.count * 99 / 100]
        #expect(p99 < .milliseconds(1))
        #expect(counts == [10_000, 7_500, 2_500, 5_000])
    }
}
