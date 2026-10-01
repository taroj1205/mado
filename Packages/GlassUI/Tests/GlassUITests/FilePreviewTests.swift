import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct FilePreviewTests {
    private let launcher = CGRect(x: 100, y: 300, width: 760, height: 476)

    @Test func sitsRightOfTheLauncherAndCentredOnIt() {
        let frame = FilePreview.frame(
            beside: launcher, in: CGRect(x: 0, y: 0, width: 1_600, height: 1_000))
        #expect(frame == CGRect(x: 892, y: 268, width: 400, height: 540))
    }

    @Test func movesLeftWhenTheLeftHasMoreRoom() {
        let anchor = launcher.offsetBy(dx: 700, dy: 0)
        let frame = FilePreview.frame(
            beside: anchor, in: CGRect(x: 0, y: 0, width: 1_600, height: 1_000))
        #expect(frame.maxX == anchor.minX - FilePreview.gap)
        #expect(frame.width == FilePreview.width)
    }

    @Test func narrowsToTheRoomBesideACentredLauncherAndStaysOnScreen() {
        let visible = CGRect(x: 0, y: 0, width: 1_512, height: 900)
        let anchor = CGRect(x: 376, y: 300, width: 760, height: 476)
        let frame = FilePreview.frame(beside: anchor, in: visible)
        #expect(frame.minX == anchor.maxX + FilePreview.gap)
        #expect(frame.maxX == visible.maxX - FilePreview.edge)
        #expect(visible.contains(frame))
    }

    @Test func overlapsRatherThanLeavingTheScreenWhenThereIsNoRoom() {
        let visible = CGRect(x: 0, y: 0, width: 900, height: 500)
        let frame = FilePreview.frame(
            beside: CGRect(x: 70, y: 12, width: 760, height: 476), in: visible)
        #expect(frame.width == FilePreview.minimumWidth)
        #expect(visible.contains(frame))
    }
}
