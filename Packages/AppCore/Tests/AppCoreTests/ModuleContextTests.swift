import Foundation
import Testing

@testable import AppCore

@MainActor
@Suite struct ModuleContextTests {
    @Test func anObserverHearsNotificationsUntilReleased() {
        let center = NotificationCenter()
        let name = Notification.Name("ping")
        let context = ModuleContext(
            moduleID: "keyboard", commands: CommandRegistry(), eventTap: EventTap())
        var heard = 0
        context.observe("pings", name, in: center) { heard += 1 }
        #expect(
            context.active == [ActiveResource(module: "keyboard", kind: .observer, name: "pings")])

        center.post(name: name, object: nil)
        #expect(heard == 1)

        context.releaseAll()
        center.post(name: name, object: nil)
        #expect(heard == 1)
        #expect(context.active.isEmpty)
    }
}
