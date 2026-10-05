import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct PasteStackHUDTests {
    private let hud = PasteStackHUD()

    private static func texts(in view: NSView) -> [String] {
        view.subviews.flatMap { subview in
            (subview as? NSTextField).map { [$0.stringValue] } ?? texts(in: subview)
        }
    }

    @Test func numbersTheStackAndMarksTheNextAndPastedItems() {
        hud.show(
            [
                .init(title: "12 Queen Street", state: .next),
                .init(title: "Auckland 1010", state: .waiting),
                .init(title: "Taro Yamada", state: .pasted),
            ], left: 2
        ) { CGRect(origin: CGPoint(x: 100, y: 100), size: $0) }
        defer { hud.hide() }

        #expect(hud.count.stringValue == "PASTE STACK · 2 LEFT")
        #expect(
            hud.rows.arrangedSubviews.map(Self.texts) == [
                ["1", "12 Queen Street", "next"], ["2", "Auckland 1010", ""],
                ["3", "Taro Yamada", "pasted"],
            ])
        #expect(hud.rows.arrangedSubviews.map(\.alphaValue) == [1, 1, 0.4])
        #expect(hud.panel.isVisible)
        #expect(hud.panel.ignoresMouseEvents)
        #expect(hud.panel.frame.width == PasteStackHUD.width)
    }

    @Test func asksToCopyWhileTheStackIsEmpty() {
        hud.show([], left: 0) { CGRect(origin: .zero, size: $0) }
        defer { hud.hide() }

        #expect(hud.count.stringValue == "PASTE STACK · 0 LEFT")
        #expect(hud.rows.arrangedSubviews.map(Self.texts) == [[PasteStackHUD.emptyHint]])
    }

    @Test func asksWhereToGoEachTimeItChangesSize() {
        let row = PasteStackHUD.Row(title: "Auckland 1010", state: .waiting)
        var sizes: [CGSize] = []
        let place = { (size: CGSize) in
            sizes.append(size)
            return CGRect(origin: CGPoint(x: 100, y: 400 - size.height), size: size)
        }
        hud.show([row], left: 1, placing: place)
        defer { hud.hide() }

        hud.show([row, row, row], left: 3, placing: place)

        #expect(sizes.count == 2)
        #expect(sizes[1].height > sizes[0].height)
        #expect(hud.panel.frame == place(sizes[1]))
    }

    @Test func showsOnlyTheFirstRowsOfALongStack() {
        let rows = Array(
            repeating: PasteStackHUD.Row(title: "Auckland 1010", state: .waiting), count: 20)
        hud.show(rows, left: 20) { CGRect(origin: .zero, size: $0) }
        defer { hud.hide() }

        #expect(hud.rows.arrangedSubviews.count == PasteStackHUD.shownRows)
    }
}
