public import CoreGraphics
import Foundation

public struct PixelLoupe {
    public struct Snapshot {
        public let image: CGImage
        public let frame: CGRect

        var scale: CGFloat {
            CGFloat(image.width) / frame.width
        }

        public init(image: CGImage, frame: CGRect) {
            self.image = image
            self.frame = frame
        }

        public func crop(_ area: CGRect) -> CGImage? {
            guard area.width > 0, area.height > 0, frame.contains(area) else { return nil }
            return image.cropping(
                to: CGRect(
                    x: (area.minX - frame.minX) * scale, y: (frame.maxY - area.maxY) * scale,
                    width: area.width * scale, height: area.height * scale
                ).integral)
        }

        func holds(_ point: CGPoint) -> Bool {
            point.x >= frame.minX && point.x < frame.maxX && point.y > frame.minY
                && point.y <= frame.maxY
        }
    }

    public struct Sample {
        public let grid: CGImage
        public let red: Int
        public let green: Int
        public let blue: Int
        public let column: Int
        public let row: Int
        public let centre: CGPoint
    }

    private static let reach = 4
    public static let span = reach + 1 + reach
    private static let channels = 4
    private static let blueOffset = 2
    private static let bitsPerComponent = 8
    private static let half: CGFloat = 0.5

    private let snapshots: [Snapshot]
    private var screen = 0
    private var column = 0
    private var row = 0

    public var sample: Sample? {
        guard snapshots.indices.contains(screen) else { return nil }
        let snapshot = snapshots[screen]
        guard let grid = Self.grid(of: snapshot.image, around: column, row),
            let bytes = grid.dataProvider?.data as Data?
        else { return nil }
        let centre = Self.reach * grid.bytesPerRow + Self.reach * Self.channels
        guard bytes.count >= centre + Self.channels else { return nil }
        return Sample(
            grid: grid, red: Int(bytes[centre]), green: Int(bytes[centre + 1]),
            blue: Int(bytes[centre + Self.blueOffset]), column: column, row: row,
            centre: CGPoint(
                x: snapshot.frame.minX + (CGFloat(column) + Self.half) / snapshot.scale,
                y: snapshot.frame.maxY - (CGFloat(row) + Self.half) / snapshot.scale))
    }

    public init(snapshots: [Snapshot]) {
        self.snapshots = snapshots.filter { $0.frame.width > 0 && $0.image.width > 0 }
    }

    private static func grid(of image: CGImage, around column: Int, _ row: Int) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = unsafe CGContext(
                data: nil, width: span, height: span, bitsPerComponent: bitsPerComponent,
                bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.interpolationQuality = .none
        context.draw(
            image,
            in: CGRect(
                x: reach - column, y: row + reach + 1 - image.height, width: image.width,
                height: image.height))
        return context.makeImage()
    }

    public mutating func move(to point: CGPoint) {
        guard let index = snapshots.firstIndex(where: { $0.holds(point) }) else { return }
        let snapshot = snapshots[index]
        screen = index
        place(
            Int(((point.x - snapshot.frame.minX) * snapshot.scale).rounded(.down)),
            Int(((snapshot.frame.maxY - point.y) * snapshot.scale).rounded(.down)))
    }

    public mutating func nudge(across: Int, down: Int) {
        place(column + across, row + down)
    }

    private mutating func place(_ newColumn: Int, _ newRow: Int) {
        guard snapshots.indices.contains(screen) else { return }
        let image = snapshots[screen].image
        column = min(max(newColumn, 0), image.width - 1)
        row = min(max(newRow, 0), image.height - 1)
    }
}
