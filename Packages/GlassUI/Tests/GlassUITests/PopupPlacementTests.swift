import AppKit
import Testing

@testable import GlassUI

@Suite struct PopupPlacementTests {
    private let bounds = NSRect(x: 10, y: 10, width: 1_000, height: 700)
    private let size = NSSize(width: 244, height: 200)

    @Test func aMenuHangsFromThePointWhenThereIsRoom() {
        let frame = PopupPlacement.frame(
            of: size, hangingFrom: NSPoint(x: 300, y: 500), in: bounds)
        #expect(frame == NSRect(x: 300, y: 300, width: 244, height: 200))
    }

    @Test func aMenuIsPushedBackIntoTheBoundsFromEveryEdge() {
        let right = PopupPlacement.frame(of: size, hangingFrom: NSPoint(x: 990, y: 500), in: bounds)
        #expect(right.maxX == bounds.maxX)
        let bottom = PopupPlacement.frame(of: size, hangingFrom: NSPoint(x: 300, y: 50), in: bounds)
        #expect(bottom.minY == bounds.minY)
        let left = PopupPlacement.frame(of: size, hangingFrom: NSPoint(x: -40, y: 500), in: bounds)
        #expect(left.minX == bounds.minX)
        let top = PopupPlacement.frame(of: size, hangingFrom: NSPoint(x: 300, y: 900), in: bounds)
        #expect(top.maxY == bounds.maxY)
    }

    @Test func aMenuTallerThanTheBoundsShrinksToThem() {
        let tall = NSSize(width: 244, height: 900)
        let frame = PopupPlacement.frame(of: tall, hangingFrom: NSPoint(x: 300, y: 500), in: bounds)
        #expect(frame.height == bounds.height)
        #expect(frame.minY == bounds.minY)
    }

    @Test func aSubmenuOpensToTheRightAndLevelWithTheTop() {
        let anchor = NSRect(x: 300, y: 300, width: 244, height: 200)
        let frame = submenu(of: anchor, in: bounds)
        #expect(frame.minX == anchor.maxX + 8)
        #expect(frame.maxY == anchor.maxY)
    }

    @Test func aSubmenuFlipsLeftWhenTheRightIsFull() {
        let anchor = NSRect(x: 740, y: 300, width: 244, height: 200)
        let frame = submenu(of: anchor, in: bounds)
        #expect(frame.maxX == anchor.minX - 8)
    }

    @Test func aSubmenuCanPreferTheLeftAndFallBackToTheRight() {
        let middle = NSRect(x: 400, y: 300, width: 244, height: 200)
        let left = PopupPlacement.frame(
            of: size, beside: middle, gap: 8, leftFirst: true, in: bounds)
        #expect(left.maxX == middle.minX - 8)
        let edge = NSRect(x: 20, y: 300, width: 244, height: 200)
        let right = PopupPlacement.frame(
            of: size, beside: edge, gap: 8, leftFirst: true, in: bounds)
        #expect(right.minX == edge.maxX + 8)
    }

    @Test func aSubmenuThatFitsNeitherSideStaysInsideTheBounds() {
        let narrow = NSRect(x: 10, y: 10, width: 300, height: 700)
        let anchor = NSRect(x: 30, y: 300, width: 244, height: 200)
        let frame = submenu(of: anchor, in: narrow)
        #expect(narrow.contains(frame))
    }

    @Test func aSubmenuNearTheBottomIsLiftedOntoTheScreen() {
        let anchor = NSRect(x: 300, y: 60, width: 244, height: 100)
        let frame = submenu(of: anchor, in: bounds)
        #expect(frame.minY == bounds.minY)
    }

    private func submenu(of anchor: NSRect, in area: NSRect) -> NSRect {
        PopupPlacement.frame(of: size, beside: anchor, gap: 8, leftFirst: false, in: area)
    }
}
