import AppKit
import CoreImage
import Testing

@testable import GlassUI

@MainActor
@Suite struct SwitcherOverlayTests {
    static let card = CGSize(width: 168, height: 154)
    static let wide = CGSize(width: 1_140, height: 600)

    private static func cards(_ count: Int) -> [SwitcherOverlay.Card] {
        (0..<count).map { index in
            SwitcherOverlay.Card(title: "Window \(index)", app: "App", icon: nil, thumbnail: nil)
        }
    }

    @Test func sixCardsFitOneRowOfTheBoardWidth() {
        let grid = SwitcherGrid(count: 6, card: Self.card, fitting: Self.wide)
        #expect(grid.columns == 6)
        #expect(grid.rows == 1)
        #expect(grid.size == CGSize(width: 14 + 6 * 168 + 5 * 10 + 14, height: 14 + 154 + 14))
        #expect(grid.origin(of: 1, firstRow: 0) == CGPoint(x: 14 + 168 + 10, y: 14))
    }

    @Test func extraCardsWrapAndScrollToTheSelectedRow() {
        let grid = SwitcherGrid(
            count: 20, card: Self.card, fitting: CGSize(width: 1_140, height: 360))
        #expect(grid.columns == 6)
        #expect(grid.rows == 2)
        #expect(grid.firstRow(showing: 5, from: 0) == 0)
        #expect(grid.firstRow(showing: 19, from: 0) == 2)
        #expect(grid.firstRow(showing: 7, from: 2) == 1)
        #expect(grid.origin(of: 0, firstRow: 1) == nil)
        #expect(grid.origin(of: 18, firstRow: 2) == CGPoint(x: 14, y: 14 + 154 + 10))
    }

    @Test func aTinyLimitStillShowsOneCard() {
        let grid = SwitcherGrid(count: 3, card: Self.card, fitting: .zero)
        #expect(grid.columns == 1)
        #expect(grid.rows == 1)
    }

    @Test func showsTheSelectedCardAndCountOnTheScreen() throws {
        let overlay = SwitcherOverlay()
        let screen = try #require(NSScreen.screens.first)
        overlay.show(Self.cards(6), selected: 1, on: screen)
        defer { overlay.hide() }

        #expect(overlay.isVisible)
        #expect(overlay.hint.isVisible)
        #expect(overlay.cards.map(\.selected) == [false, true, false, false, false, false])
        #expect(overlay.count.stringValue == "2 of 6 windows")
        #expect(overlay.hint.frame.maxY < overlay.panel.frame.minY)
        #expect(overlay.hint.frame.width > 400)
        #expect(abs(overlay.hint.frame.midX - overlay.panel.frame.midX) <= 1)
        #expect(screen.visibleFrame.contains(overlay.panel.frame))

        overlay.select(5)
        #expect(overlay.cards.map(\.selected) == [false, false, false, false, false, true])
        #expect(overlay.count.stringValue == "6 of 6 windows")
    }

    @Test func picksAndHoversReportTheCardIndex() {
        let overlay = SwitcherOverlay()
        var picked: [Int] = []
        var hovered: [Int] = []
        overlay.onPick = { picked.append($0) }
        overlay.onHover = { hovered.append($0) }
        overlay.pointer = { .zero }
        overlay.show(Self.cards(2), selected: 0, on: NSScreen.screens[0])
        defer { overlay.hide() }

        #expect(overlay.cards[1].accessibilityPerformPress())
        overlay.cards[1].mouseEntered(with: NSEvent())
        overlay.pointer = { CGPoint(x: 1, y: 1) }
        overlay.cards[0].mouseEntered(with: NSEvent())
        #expect(picked == [1])
        #expect(hovered == [0])
        #expect(overlay.count.stringValue == "1 of 2 windows")
        #expect(overlay.cards[1].accessibilityLabel() == "App: Window 1")
    }

    @Test func capturedThumbnailsReplaceThePlaceholders() throws {
        let overlay = SwitcherOverlay()
        overlay.show(Self.cards(3), selected: 0, on: NSScreen.screens[0])
        defer { overlay.hide() }
        let square = CGRect(x: 0, y: 0, width: 4, height: 3)
        let image = try #require(
            CIContext().createCGImage(CIImage(color: .red).cropped(to: square), from: square))

        overlay.showThumbnail(image, at: 1)
        overlay.showThumbnail(image, at: 3)
        #expect(overlay.cards.map { $0.thumbnail.image != nil } == [false, true, false])
        #expect(SwitcherOverlay.thumbnailSize == CGSize(width: 272, height: 170))
    }

    @Test func hideTakesDownEveryWindow() {
        let overlay = SwitcherOverlay()
        overlay.show(Self.cards(1), selected: 0, on: NSScreen.screens[0])
        #expect(overlay.count.stringValue == "1 of 1 window")
        overlay.hide()
        #expect(!overlay.isVisible)
        #expect(!overlay.hint.isVisible)
    }
}
