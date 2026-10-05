import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct LauncherCapsuleTests {
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 760, height: 476),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let view = LauncherView()

    init() {
        panel.contentView = view
        view.results.sections = [
            .init(
                title: "Applications",
                items: [
                    .init(
                        id: "Safari", title: "Safari", subtitle: "", kind: "", symbol: "",
                        action: "Open")
                ])
        ]
    }

    @Test func refreshingPillsAndWidgetsLeavesTheCapsuleViewsInPlace() {
        let before = capsuleViews()
        for value in ["10", "20"] {
            view.pills = [
                .init(id: "cpu", name: "CPU", symbol: "cpu", value: value, action: "Open")
            ]
            view.widgets = []
        }
        #expect(!before.isEmpty)
        #expect(capsuleViews() == before)
    }

    private func capsuleViews() -> [NSView] {
        view.layoutSubtreeIfNeeded()
        return (view.actionCapsule.contentView as? NSStackView)?.arrangedSubviews ?? []
    }
}
