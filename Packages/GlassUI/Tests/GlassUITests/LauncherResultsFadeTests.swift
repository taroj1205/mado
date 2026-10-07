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

    @Test func clicksInTheFadedBandNeverReachTheRowsBeneathIt() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 476),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentView = launcher
        launcher.results.sections = [
            .init(
                title: "Commands",
                items: (0..<40).map { index in
                    .init(
                        id: "\(index)", title: "Command \(index)", subtitle: "", kind: "Command",
                        symbol: "star", action: "Run Command")
                })
        ]
        launcher.layoutSubtreeIfNeeded()
        let results = launcher.results
        let inset = results.contentInsets.bottom
        func hit(offsetFromBottom: CGFloat) -> NSView? {
            results.hitTest(NSPoint(x: results.bounds.midX, y: offsetFromBottom))
        }
        #expect(hit(offsetFromBottom: inset + 1)?.isDescendant(of: results.table) == true)
        #expect(hit(offsetFromBottom: inset - 1) === results)
    }
}
