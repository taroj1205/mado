public import AppKit

public enum LyricsBarSpot {
    public struct Screen: Equatable, Sendable {
        public var frame: NSRect
        public var visibleFrame: NSRect
        public var notchEdge: CGFloat?

        public init(frame: NSRect, visibleFrame: NSRect, notchEdge: CGFloat? = nil) {
            self.frame = frame
            self.visibleFrame = visibleFrame
            self.notchEdge = notchEdge
        }
    }

    static let height: CGFloat = 22
    static let gap: CGFloat = 16
    static let widths: ClosedRange<CGFloat> = 140...300
    private static let half: CGFloat = 0.5
    private static let slack: CGFloat = 1

    public static func frame(
        for pin: LyricsPin, around surroundings: LyricsSurroundings, on screen: Screen
    ) -> NSRect? {
        switch pin {
        case .dock: dock(surroundings, on: screen)
        case .menus: menus(surroundings, on: screen)
        case .corner, .desktop, .island, .menuBar: nil
        }
    }

    private static func dock(_ surroundings: LyricsSurroundings, on screen: Screen) -> NSRect? {
        let inset = screen.visibleFrame.minY - screen.frame.minY
        guard let items = surroundings.dock, inset >= height,
            screen.visibleFrame.minX == screen.frame.minX,
            screen.visibleFrame.maxX == screen.frame.maxX,
            items.intersects(screen.frame)
        else { return nil }
        let before = items.minX - screen.frame.minX
        let after = screen.frame.maxX - items.maxX
        return before > after
            ? fit(from: screen.frame.minX, to: items.minX, atStart: false, centre: items.midY)
            : fit(from: items.maxX, to: screen.frame.maxX, atStart: true, centre: items.midY)
    }

    private static func menus(_ surroundings: LyricsSurroundings, on screen: Screen) -> NSRect? {
        let thickness = screen.frame.maxY - screen.visibleFrame.maxY
        guard let end = surroundings.menusEnd, thickness >= height else {
            return nil
        }
        let band = NSRect(
            x: screen.frame.minX, y: screen.visibleFrame.maxY, width: screen.frame.width,
            height: thickness)
        let items = surroundings.statusItems.filter { item in
            item.intersects(band) && item.height <= thickness + slack
        }
        let limits = [screen.frame.maxX, screen.notchEdge].compactMap(\.self) + items.map(\.minX)
        return fit(
            from: screen.frame.minX + end, to: limits.min() ?? screen.frame.maxX, atStart: true,
            centre: band.midY)
    }

    private static func fit(
        from lower: CGFloat, to upper: CGFloat, atStart: Bool, centre: CGFloat
    ) -> NSRect? {
        let room = upper - lower - gap - gap
        guard room >= widths.lowerBound else { return nil }
        let width = min(room, widths.upperBound)
        return NSRect(
            x: atStart ? lower + gap : upper - gap - width,
            y: (centre - height * half).rounded(), width: width,
            height: height)
    }
}
