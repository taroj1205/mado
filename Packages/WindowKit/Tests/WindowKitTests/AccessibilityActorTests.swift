import ApplicationServices
import Foundation
import Testing

@testable import WindowKit

@Suite struct AccessibilityActorTests {
    @AccessibilityActor
    @Test func requestsToThisProcessRunOnTheMainThread() {
        let own = AXUIElementCreateApplication(getpid())
        let other = AXUIElementCreateApplication(1)
        #expect(AccessibilityActor.call(on: own) { Thread.isMainThread })
        #expect(!AccessibilityActor.call(on: other) { Thread.isMainThread })
    }
}
