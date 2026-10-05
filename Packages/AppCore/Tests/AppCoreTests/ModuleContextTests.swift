import CoreGraphics
import Foundation
import Testing

@testable import AppCore

@MainActor
@Suite struct ModuleContextTests {
    private static let name = Notification.Name("frontmost")

    @Test func anObserverDeliversUntilReleased() {
        let center = NotificationCenter()
        let context = ModuleContext(
            moduleID: "keyboard", commands: CommandRegistry(), eventTap: EventTap(),
            listenTap: EventTap(options: .listenOnly))
        var received: [String?] = []
        context.observe(
            Self.name, on: center, reading: { $0.object as? String },
            handler: { app in received.append(app) })
        #expect(
            context.active == [
                ActiveResource(module: "keyboard", kind: .observer, name: Self.name.rawValue)
            ])

        center.post(name: Self.name, object: "Terminal")
        #expect(received == ["Terminal"])

        context.releaseAll()
        center.post(name: Self.name, object: "Xcode")
        #expect(received == ["Terminal"])
        #expect(context.active.isEmpty)
    }

    @Test func aHandlerKeptUntilStoppedDropsWhatArrivesAfterTheRelease() {
        let context = ModuleContext(
            moduleID: "windows", commands: CommandRegistry(), eventTap: EventTap(),
            listenTap: EventTap(options: .listenOnly))
        var received: [String] = []
        let beforePause = context.untilStopped { (event: String) in received.append(event) }

        beforePause("pressed")
        context.releaseAll()
        let afterResume = context.untilStopped { (event: String) in received.append(event) }
        beforePause("queued before the pause")
        afterResume("pressed again")

        #expect(received == ["pressed", "pressed again"])
    }
}
