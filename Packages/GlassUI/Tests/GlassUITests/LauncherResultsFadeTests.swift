import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct LauncherResultsFadeTests {
    private let launcher = LauncherView()

    @Test func rowsFadeOutAcrossTheMarginAboveTheFloatingControls() throws {
        launcher.layoutSubtreeIfNeeded()
        let height = launcher.results.bounds.height
        let inset = launcher.results.contentInsets.bottom
        let locations = try #require(launcher.resultsFade.locations).map { CGFloat($0.doubleValue) }
        let expected = [
            0, (height - inset) / height, (height - inset + LauncherView.capsuleInset) / height, 1,
        ]
        #expect(locations.count == expected.count)
        for (shown, wanted) in zip(locations, expected) {
            #expect(abs(shown - wanted) < 0.0001)
        }
        #expect(inset > LauncherView.capsuleInset)
        #expect(launcher.resultsFade.frame == launcher.results.bounds)
        #expect(launcher.results.layer?.mask === launcher.resultsFade)
    }
}
