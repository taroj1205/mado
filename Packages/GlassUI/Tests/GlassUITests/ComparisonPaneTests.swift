import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct ComparisonPaneTests {
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 760, height: 476),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let view = LauncherView()

    init() {
        panel.contentView = view
    }

    private static func tool(_ title: String, dimmed: Bool) -> ResultList.Item {
        var item = ResultList.Item(
            id: title, title: title, subtitle: "", kind: "", symbol: "textformat",
            action: dimmed ? "" : "Replace Selection")
        item.isDimmed = dimmed
        return item
    }

    private static func comparison(of item: ResultList.Item) -> LauncherView.Comparison {
        .init(
            source: ("Selected in", "Notes"), counts: "2 lines", before: "a\na",
            struck: [1], after: item.isDimmed ? "Nothing to trim" : "a",
            changes: !item.isDimmed)
    }

    @Test func aChipScopeShowsTheSearchIconChipAndAWideListBesideTheComparison() {
        view.enter(
            placeholder: "Filter tools",
            chip: .init(title: "Selected text", symbol: "text.alignleft"),
            detail: .comparison(Self.comparison))
        view.show([
            .init(
                title: "Text Tools",
                items: [Self.tool("Dedupe", dimmed: false), Self.tool("Trim", dimmed: true)])
        ])
        view.layoutSubtreeIfNeeded()

        #expect(!view.icon.isHidden && view.back.isHidden && !view.chip.isHidden)
        #expect(view.field.frame.minX > view.chip.frame.maxX)
        #expect(view.results.frame.width == 384)
        #expect(!view.comparisonPane.isHidden && view.detail.isHidden)
        #expect(!view.results.compact)

        #expect(view.chip.accessibilityPerformPress())

        #expect(view.chip.isHidden && view.comparisonPane.isHidden && !view.scoped)
    }

    @Test func dimmedRowsFadeAndTheirComparisonExplainsWhy() throws {
        view.capsuleSlots = [.primary, .keyed(LauncherView.Action.secondaryKeys)]
        view.enter(placeholder: "Filter tools", detail: .comparison(Self.comparison))
        view.show([.init(title: "Text Tools", items: [Self.tool("Trim", dimmed: true)])])
        view.layoutSubtreeIfNeeded()
        let cell = view.results.table.view(atColumn: 0, row: 1, makeIfNecessary: true)

        #expect(cell?.alphaValue == 0.45)
        #expect(view.actionCapsule.isHidden)
        let before = try AttributedString(
            view.comparisonPane.before.text.attributedStringValue, including: \.appKit)
        let struck = before.runs.filter { $0.appKit.strikethroughStyle != nil }
        #expect(struck.map { String(before[$0.range].characters) } == ["a"])
        #expect(view.comparisonPane.after.text.stringValue == "Nothing to trim")
    }
}
