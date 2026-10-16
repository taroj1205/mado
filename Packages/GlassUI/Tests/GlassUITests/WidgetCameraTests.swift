import AppKit
import AVFoundation
import Testing

@testable import GlassUI

@MainActor
@Suite struct WidgetCameraTests {
    private let tile = WidgetTile(floating: false)
    private let session = AVCaptureSession()

    init() {
        tile.frame = NSRect(x: 0, y: 0, width: 200, height: 164)
    }

    private func live(mirrored: Bool = true) -> WidgetGrid.Widget {
        .init(
            id: "camera", name: "Camera",
            live: .init(session: session, mirrored: mirrored), action: "Open Camera",
            spoken: "Camera: live preview")
    }

    @Test func aLiveCameraFillsTheTileInsideASmallBezel() throws {
        tile.show(live())
        tile.layoutSubtreeIfNeeded()
        let preview = try #require(tile.camera.subviews.first as? CameraPreview)
        #expect(!tile.camera.isHidden)
        #expect(tile.camera.frame == tile.bounds.insetBy(dx: 4, dy: 4))
        #expect(preview.frame == tile.camera.bounds)
    }

    @Test func theSameSessionKeepsItsPreviewWhileTheMirrorSettingFollowsTheWidget() throws {
        tile.show(live())
        let first = try #require(tile.camera.subviews.first as? CameraPreview)
        tile.show(live(mirrored: false))
        #expect(tile.camera.subviews.count == 1)
        #expect(tile.camera.subviews.first === first)
        #expect(!first.isMirrored)
    }

    @Test func anotherWidgetHidesTheCamera() {
        tile.show(live())
        tile.show(
            .init(
                id: "clock", name: "Clock", value: "9:41", detail: "Wed 30 Sep",
                action: "Open Clock", spoken: "Time: 9:41 AM"))
        #expect(tile.camera.isHidden)
    }

    @Test func aLiveCameraIsWideAndTallLikeTheOtherMediaWidgets() {
        let widget = live()
        #expect(widget.isWide)
        #expect(widget.isTall)
        #expect(widget.isLive)
    }

    @Test func sessionsAndMirroringDecideWhetherTwoFeedsMatch() {
        let first = WidgetGrid.Live(session: session, mirrored: true)
        #expect(first == WidgetGrid.Live(session: session, mirrored: true))
        #expect(first != WidgetGrid.Live(session: session, mirrored: false))
        #expect(first != WidgetGrid.Live(session: AVCaptureSession(), mirrored: true))
    }
}
