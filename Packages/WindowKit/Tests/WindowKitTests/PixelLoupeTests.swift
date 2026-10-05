import CoreGraphics
import Foundation
import Testing

@testable import WindowKit

@Suite struct PixelLoupeTests {
    static let byte: CGFloat = 255

    private static func image(width: Int, height: Int, blue: Int = 7) throws -> CGImage {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(
            unsafe CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        for column in 0..<width {
            for row in 0..<height {
                context.setFillColor(
                    CGColor(
                        srgbRed: CGFloat(column * 10) / byte, green: CGFloat(row * 10) / byte,
                        blue: CGFloat(blue) / byte, alpha: 1))
                context.fill(CGRect(x: column, y: height - 1 - row, width: 1, height: 1))
            }
        }
        return try #require(context.makeImage())
    }

    private static func loupe() throws -> PixelLoupe {
        PixelLoupe(snapshots: [
            PixelLoupe.Snapshot(
                image: try image(width: 20, height: 10),
                frame: CGRect(x: 100, y: 50, width: 10, height: 5)),
            PixelLoupe.Snapshot(
                image: try image(width: 8, height: 8, blue: 200),
                frame: CGRect(x: 110, y: 50, width: 8, height: 8)),
        ])
    }

    private static func pixel(_ sample: PixelLoupe.Sample) -> [Int] {
        [sample.column, sample.row]
    }

    private static func rgb(_ sample: PixelLoupe.Sample) -> [Int] {
        [sample.red, sample.green, sample.blue]
    }

    private static func alpha(of grid: CGImage, column: Int, row: Int) throws -> UInt8 {
        let bytes = try #require(grid.dataProvider?.data as Data?)
        return bytes[row * grid.bytesPerRow + column * 4 + 3]
    }

    private static func topLeft(of image: CGImage) throws -> [Int] {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(
            unsafe CGContext(
                data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(
            image, in: CGRect(x: 0, y: 1 - image.height, width: image.width, height: image.height))
        let bytes = try #require(context.makeImage()?.dataProvider?.data as Data?)
        return bytes[0..<3].map(Int.init)
    }

    @Test func thePointerPicksThePixelUnderItOnARetinaSnapshot() throws {
        var loupe = try Self.loupe()
        loupe.move(to: CGPoint(x: 103.6, y: 53.2))
        let sample = try #require(loupe.sample)
        #expect(Self.pixel(sample) == [7, 3])
        #expect(Self.rgb(sample) == [70, 30, 7])
        #expect(sample.centre == CGPoint(x: 103.75, y: 53.25))
    }

    @Test func theGridIsNinePixelsSquareAroundThePickedPixel() throws {
        var loupe = try Self.loupe()
        loupe.move(to: CGPoint(x: 105, y: 52.5))
        let sample = try #require(loupe.sample)
        #expect(sample.grid.width == PixelLoupe.span)
        #expect(sample.grid.height == PixelLoupe.span)
        let bytes = try #require(sample.grid.dataProvider?.data as Data?)
        let corner: [UInt8] = Array(bytes[0..<4])
        #expect(corner == [UInt8((sample.column - 4) * 10), UInt8((sample.row - 4) * 10), 7, 255])
    }

    @Test func cellsPastTheScreenEdgeStayEmpty() throws {
        var loupe = try Self.loupe()
        loupe.move(to: CGPoint(x: 100, y: 55))
        let sample = try #require(loupe.sample)
        #expect(Self.pixel(sample) == [0, 0])
        #expect(try Self.alpha(of: sample.grid, column: 3, row: 4) == 0)
        #expect(try Self.alpha(of: sample.grid, column: 4, row: 3) == 0)
        #expect(try Self.alpha(of: sample.grid, column: 4, row: 4) == 255)
    }

    @Test func arrowNudgesMoveOnePixelAndStopAtTheEdge() throws {
        var loupe = try Self.loupe()
        loupe.move(to: CGPoint(x: 109.9, y: 50.1))
        loupe.nudge(across: -1, down: 0)
        var sample = try #require(loupe.sample)
        #expect(Self.pixel(sample) == [18, 9])
        loupe.nudge(across: 5, down: 3)
        sample = try #require(loupe.sample)
        #expect(Self.pixel(sample) == [19, 9])
        #expect(Self.rgb(sample) == [190, 90, 7])
    }

    @Test func movingOntoAnotherScreenSamplesItsSnapshot() throws {
        var loupe = try Self.loupe()
        loupe.move(to: CGPoint(x: 110, y: 58))
        let sample = try #require(loupe.sample)
        #expect(Self.pixel(sample) == [0, 0])
        #expect(sample.blue == 200)
        #expect(sample.centre == CGPoint(x: 110.5, y: 57.5))
    }

    @Test func aPointerBetweenScreensKeepsThePreviousPixel() throws {
        var loupe = try Self.loupe()
        loupe.move(to: CGPoint(x: 102, y: 54))
        loupe.move(to: CGPoint(x: 400, y: 400))
        let sample = try #require(loupe.sample)
        #expect(Self.pixel(sample) == [4, 2])
    }

    @Test func noSnapshotsGiveNoSample() {
        var loupe = PixelLoupe(snapshots: [])
        loupe.move(to: .zero)
        loupe.nudge(across: 1, down: 1)
        #expect(loupe.sample == nil)
    }

    @Test func cropsTheAreaOfARetinaSnapshotInPixels() throws {
        let snapshot = PixelLoupe.Snapshot(
            image: try Self.image(width: 20, height: 10),
            frame: CGRect(x: 100, y: 50, width: 10, height: 5))
        let crop = try #require(snapshot.crop(CGRect(x: 102, y: 51, width: 4, height: 2)))
        #expect(crop.width == 8)
        #expect(crop.height == 4)
        #expect(try Self.topLeft(of: crop) == [40, 40, 7])
        let whole = try #require(snapshot.crop(snapshot.frame))
        #expect(whole.width == 20)
        #expect(whole.height == 10)
    }

    @Test func refusesAnAreaThatLeavesTheSnapshotOrHasNoSize() throws {
        let snapshot = PixelLoupe.Snapshot(
            image: try Self.image(width: 20, height: 10),
            frame: CGRect(x: 100, y: 50, width: 10, height: 5))
        #expect(snapshot.crop(CGRect(x: 108, y: 51, width: 4, height: 2)) == nil)
        #expect(snapshot.crop(CGRect(x: 300, y: 300, width: 4, height: 2)) == nil)
        #expect(snapshot.crop(CGRect(x: 102, y: 51, width: 0, height: 2)) == nil)
    }
}
