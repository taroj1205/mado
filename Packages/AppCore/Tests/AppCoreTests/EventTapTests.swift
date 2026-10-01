import ApplicationServices
import CoreGraphics
import Testing

@testable import AppCore

@MainActor
@Suite(.enabled(if: AXIsProcessTrusted(), "Active event taps need Accessibility"))
struct EventTapTests {
    @Test(arguments: [CGEventType.tapDisabledByTimeout, .tapDisabledByUserInput])
    func aStoppedTapIsReenabledRightAway(reason: CGEventType) throws {
        let tap = try #require(EventTap(types: [.flagsChanged]) { _, _ in false })
        defer { tap.invalidate() }
        let port = try #require(tap.port)
        let event = try #require(CGEvent(source: nil))

        CGEvent.tapEnable(tap: port, enable: false)
        #expect(!CGEvent.tapIsEnabled(tap: port))
        #expect(tap.handle(reason, event))
        #expect(CGEvent.tapIsEnabled(tap: port))
    }

    @Test func theHandlerDecidesWhatIsSwallowed() throws {
        let tap = try #require(EventTap(types: [.flagsChanged]) { type, _ in type == .keyDown })
        defer { tap.invalidate() }
        let event = try #require(CGEvent(source: nil))

        #expect(!tap.handle(.keyDown, event))
        #expect(tap.handle(.keyUp, event))
    }

    @Test func theContextOwnsTheTapUntilReleased() throws {
        let context = ModuleContext(moduleID: "radial", commands: CommandRegistry())
        try context.tapEvents("trigger", matching: [.flagsChanged]) { _, _ in false }
        #expect(
            context.active == [ActiveResource(module: "radial", kind: .eventTap, name: "trigger")])

        context.releaseAll()
        #expect(context.active.isEmpty)
    }
}
