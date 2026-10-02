import CoreGraphics
import Testing

@testable import WindowKit

@Suite struct WindowThumbnailsTests {
    static let box = CGSize(width: 304, height: 200)

    @Test func wideWindowsFitTheBoxWidth() {
        #expect(
            WindowThumbnails.size(of: CGSize(width: 1_600, height: 800), fitting: Self.box)
                == CGSize(width: 304, height: 152))
    }

    @Test func tallWindowsFitTheBoxHeight() {
        #expect(
            WindowThumbnails.size(of: CGSize(width: 500, height: 1_000), fitting: Self.box)
                == CGSize(width: 100, height: 200))
    }

    @Test func capturedImagesShrinkToFitTheBox() throws {
        let context = try #require(
            unsafe CGContext(
                data: nil, width: 1_600, height: 800, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue))
        let image = try #require(context.makeImage())
        let scaled = try #require(WindowThumbnails.scaled(image, fitting: Self.box))
        #expect(scaled.width == 304)
        #expect(scaled.height == 152)
    }

    @Test func emptyWindowsHaveNoThumbnail() {
        #expect(
            WindowThumbnails.size(of: CGSize(width: 0, height: 600), fitting: Self.box) == .zero)
    }
}
