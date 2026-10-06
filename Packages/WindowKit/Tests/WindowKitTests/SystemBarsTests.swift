import CoreGraphics
import Testing

@testable import WindowKit

@Suite struct SystemBarsTests {
    @Test func statusItemsSkipTheNamedWindow() {
        let all = SystemBars.statusItems(excluding: nil)
        #expect(all.allSatisfy { $0.width > 0 && $0.height > 0 })
        #expect(SystemBars.statusItems(excluding: CGWindowID.max).count == all.count)
    }

    @AccessibilityActor
    @Test func aProcessWithoutAMenuBarHasNoMenus() {
        #expect(SystemBars.menus(of: 1) == nil)
    }
}
