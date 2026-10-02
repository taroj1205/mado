import AppKit
import ApplicationServices
import Testing

@testable import GlassUI

@MainActor
@Suite struct OverlayPanelTests {
    private let panel = OverlayPanel()

    @Test func neverTakesTheMouseOrTheKeyboard() {
        #expect(panel.ignoresMouseEvents)
        #expect(!panel.canBecomeKey)
        #expect(!panel.canBecomeMain)
        #expect(panel.styleMask.contains(.nonactivatingPanel))
        #expect(!panel.hidesOnDeactivate)
    }

    @Test func showsOnEverySpaceAndOverFullScreenApps() {
        #expect(panel.collectionBehavior.contains(.canJoinAllSpaces))
        #expect(panel.collectionBehavior.contains(.fullScreenAuxiliary))
        #expect(panel.level == .statusBar)
    }

    @Test func hasItsWindowBeforeItIsShown() {
        #expect(!panel.isVisible)
        #expect(panel.windowNumber > 0)
    }

    @Test func showingItKeepsTheFrontmostApp() async throws {
        let front = try #require(NSWorkspace.shared.frontmostApplication)
        try await show {
            #expect(NSWorkspace.shared.frontmostApplication == front)
            #expect(!panel.isKeyWindow)
        }
    }

    @Test(.enabled(if: AXIsProcessTrusted(), "Reading another app's focus needs Accessibility"))
    func showingItKeepsTheFocusedElement() async throws {
        let focused = try #require(focusedElement())
        try await show {
            let now = try #require(focusedElement())
            #expect(CFEqual(now, focused))
        }
    }

    private func show(_ check: () throws -> Void) async throws {
        NSApp.setActivationPolicy(.accessory)
        panel.setFrame(NSRect(x: 0, y: 0, width: 120, height: 120), display: false)
        panel.makeKeyAndOrderFront(nil)
        defer { panel.orderOut(nil) }
        try await Task.sleep(for: .milliseconds(100))
        #expect(panel.isVisible)
        try check()
    }

    private func focusedElement() -> AXUIElement? {
        var value: CFTypeRef?
        let result = unsafe AXUIElementCopyAttributeValue(
            AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute as CFString, &value)
        guard result == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return unsafe unsafeDowncast(value, to: AXUIElement.self)
    }
}
