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

    @Test func emptyWindowsHaveNoThumbnail() {
        #expect(
            WindowThumbnails.size(of: CGSize(width: 0, height: 600), fitting: Self.box) == .zero)
    }
}
