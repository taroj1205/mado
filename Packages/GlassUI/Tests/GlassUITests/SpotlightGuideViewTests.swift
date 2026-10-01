import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct SpotlightGuideViewTests {
    @Test func stepsFollowSpotlightAndConfirmation() {
        let guide = SpotlightGuideView()
        #expect(guide.steps.map(\.state) == [.active, .pending, .pending])
        #expect(guide.spotlight.state == .on)

        guide.show(spotlightHasCommandSpace: false, commandSpaceReaches: false)
        #expect(guide.steps.map(\.state) == [.done, .active, .pending])
        #expect(guide.spotlight.state == .off)

        guide.show(spotlightHasCommandSpace: false, commandSpaceReaches: true)
        #expect(guide.steps.map(\.state) == [.done, .done, .done])
    }

    @Test func buttonsReportTheChoice() {
        let guide = SpotlightGuideView()
        var events: [String] = []
        guide.onUseOptionSpace = { events.append("option") }
        guide.onClose = { events.append("close") }
        guide.useOptionSpace.performClick(nil)
        guide.skip.performClick(nil)
        guide.finish.performClick(nil)
        #expect(events == ["option", "close", "close"])
    }
}
