import CoreGraphics
import Testing

@testable import GlassUI

@Suite struct AreaSelectionTests {
    static let screen = CGRect(x: 0, y: 0, width: 1_280, height: 800)

    private static func selection(
        from start: CGPoint, to end: CGPoint, in bounds: CGRect = screen
    ) -> AreaSelection {
        var selection = AreaSelection(from: start, in: bounds)
        selection.drag(to: end)
        return selection
    }

    @Test func dragsInAnyDirectionGiveTheSameRectangle() {
        let down = Self.selection(from: CGPoint(x: 190, y: 600), to: CGPoint(x: 610, y: 490))
        let reverse = Self.selection(from: CGPoint(x: 610, y: 490), to: CGPoint(x: 190, y: 600))
        #expect(down.rect == CGRect(x: 190, y: 490, width: 420, height: 110))
        #expect(reverse.rect == down.rect)
    }

    @Test func theRectangleStaysInsideTheScreen() {
        let selection = Self.selection(
            from: CGPoint(x: 1_200, y: 40), to: CGPoint(x: 1_500, y: -90))
        #expect(selection.rect == CGRect(x: 1_200, y: 0, width: 80, height: 40))
        let outside = Self.selection(from: CGPoint(x: -20, y: 900), to: CGPoint(x: 10, y: 790))
        #expect(outside.rect == CGRect(x: 0, y: 790, width: 10, height: 10))
    }

    @Test func aClickOrASliverIsNotAnArea() {
        let click = AreaSelection(from: CGPoint(x: 50, y: 50), in: Self.screen)
        #expect(!click.isUsable)
        #expect(!Self.selection(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 400, y: 52)).isUsable)
        #expect(Self.selection(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 54, y: 54)).isUsable)
    }

    @Test func theSizeReadsWidthByHeightInPoints() {
        let selection = Self.selection(
            from: CGPoint(x: 190, y: 600), to: CGPoint(x: 610.4, y: 489.6))
        #expect(selection.size == "420 × 110")
    }

    @Test func theBadgeSitsUnderTheBottomRightCorner() {
        let selection = Self.selection(from: CGPoint(x: 190, y: 600), to: CGPoint(x: 610, y: 490))
        let badge = selection.badge(sized: CGSize(width: 67, height: 16))
        #expect(badge == CGRect(x: 540, y: 470, width: 67, height: 16))
    }

    @Test func theBadgeMovesInsideAtTheBottomAndStaysOnTheLeftEdge() {
        let low = Self.selection(from: CGPoint(x: 30, y: 2), to: CGPoint(x: 40, y: 60))
        let badge = low.badge(sized: CGSize(width: 67, height: 16))
        #expect(badge.minY == low.rect.minY + 4)
        #expect(badge.minX == 0)
    }
}
