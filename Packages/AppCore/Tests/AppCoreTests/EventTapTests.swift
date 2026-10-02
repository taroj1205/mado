import ApplicationServices
import CoreGraphics
import Testing

@testable import AppCore

@MainActor
@Suite(.enabled(if: AXIsProcessTrusted(), "Active event taps need Accessibility"))
struct EventTapTests {
    @Test(arguments: [CGEventType.tapDisabledByTimeout, .tapDisabledByUserInput])
    func aStoppedTapIsReenabledRightAway(reason: CGEventType) throws {
        let tap = EventTap()
        let id = try #require(tap.add(types: [.flagsChanged]) { _, _ in false })
        defer { tap.remove(id) }
        let port = try #require(tap.port)
        let event = try #require(CGEvent(source: nil))

        CGEvent.tapEnable(tap: port, enable: false)
        #expect(!CGEvent.tapIsEnabled(tap: port))
        #expect(tap.handle(reason, event))
        #expect(CGEvent.tapIsEnabled(tap: port))
    }

    @Test func theRoutesDecideWhatIsSwallowed() throws {
        let tap = EventTap()
        let id = try #require(tap.add(types: [.keyDown, .keyUp]) { type, _ in type == .keyDown })
        defer { tap.remove(id) }
        let event = try #require(CGEvent(source: nil))

        #expect(!tap.handle(.keyDown, event))
        #expect(tap.handle(.keyUp, event))
    }

    @Test func allRoutesShareOneTapThatGoesAwayWithTheLast() throws {
        let tap = EventTap()
        let radial = try #require(tap.add(types: [.flagsChanged]) { _, _ in false })
        let first = try #require(tap.port)

        let modifier = try #require(tap.add(types: [.flagsChanged]) { _, _ in false })
        #expect(tap.port === first)

        let snippets = try #require(tap.add(types: [.keyDown]) { _, _ in false })
        let widened = try #require(tap.port)
        #expect(widened !== first)
        #expect(!CFMachPortIsValid(first))

        tap.remove(radial)
        tap.remove(modifier)
        #expect(tap.port !== widened)
        tap.remove(snippets)
        #expect(tap.port == nil)
    }

    @Test func theContextOwnsItsRouteUntilReleased() throws {
        let tap = EventTap()
        let context = ModuleContext(moduleID: "radial", commands: CommandRegistry(), eventTap: tap)
        try context.tapEvents("trigger", matching: [.flagsChanged]) { _, _ in false }
        #expect(
            context.active == [ActiveResource(module: "radial", kind: .eventTap, name: "trigger")])
        #expect(tap.port != nil)

        context.releaseAll()
        #expect(context.active.isEmpty)
        #expect(tap.port == nil)
    }
}
