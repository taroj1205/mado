import AppCore
import AppKit
import AVFoundation
import Testing

@testable import GlassUI

@MainActor
@Suite struct CameraPaneTests {
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 760, height: 500),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let view = LauncherView()
    private let window = CameraWindow(session: AVCaptureSession())

    private var surface: CameraSurface {
        get throws { try #require(view.camera.surface) }
    }

    init() {
        panel.contentView = view
        view.camera.use(AVCaptureSession())
        panel.makeFirstResponder(view.field)
    }

    private func pressReturn() -> Bool {
        view.control(
            view.field, textView: NSTextView(), doCommandBy: #selector(NSResponder.insertNewline))
    }

    @Test func showingTheCameraHidesTheResultsAndTheBarsAndRefitsThePanel() {
        var fits = 0
        view.onFit = { fits += 1 }
        view.context = "6 results"
        view.showCamera(true)
        #expect(view.showsCamera && !view.camera.isHidden)
        #expect(view.results.isHidden && view.actionCapsule.isHidden && view.contextPill.isHidden)
        #expect(fits == 1)
        view.showLyrics(false)
        #expect(view.results.isHidden)
        view.showCamera(false)
        #expect(!view.showsCamera && !view.results.isHidden)
        #expect(fits == 2)
    }

    @Test func returnTakesAPhotoOnlyOnceTheCameraIsLive() {
        var shots = 0
        view.camera.onCapture = { shots += 1 }
        view.showCamera(true)
        #expect(pressReturn())
        #expect(shots == 0)
        view.camera.setPhase(.live)
        #expect(pressReturn())
        #expect(shots == 1)
    }

    @Test func returnDoesNothingWhenTheCameraIsNotShown() {
        var shots = 0
        view.camera.onCapture = { shots += 1 }
        view.camera.setPhase(.live)
        _ = pressReturn()
        #expect(shots == 0)
    }

    @Test func showsTheControlsAtAllTimesWithoutAClosingButtonOrAResizeCorner() throws {
        let inline = try surface
        view.camera.setPhase(.live)
        #expect(inline.bar.alphaValue == 1)
        #expect(inline.closer.isHidden)
        #expect(!inline.mouseDownCanMoveWindow)
        #expect(inline.popOut.isDescendant(of: inline.bar))
        #expect(!window.surface.popOut.isDescendant(of: window.surface.bar))
        #expect(window.surface.shutter.isDescendant(of: window.surface.bar))
    }

    @Test func keepsTheBottomShadeInsideTheRoundedCorners() throws {
        let inline = try surface
        let clip = try #require(inline.subviews.first { inline.preview.isDescendant(of: $0) })
        #expect(inline.shade.isDescendant(of: clip))
        #expect(clip.layer?.masksToBounds == true)
    }

    @Test func theShutterAndThePopOutButtonReport() throws {
        var shots = 0
        var popped = 0
        view.camera.onCapture = { shots += 1 }
        view.camera.onPopOut = { popped += 1 }
        view.camera.setPhase(.live)
        try surface.shutter.performClick(nil)
        try surface.popOut.performClick(nil)
        #expect(shots == 1)
        #expect(popped == 1)
    }

    @Test func theWindowShutterTakesAPhotoToo() {
        var shots = 0
        window.onCapture = { shots += 1 }
        window.surface.shutter.performClick(nil)
        #expect(shots == 0)
        window.setPhase(.live)
        window.surface.shutter.performClick(nil)
        #expect(shots == 1)
    }

    @Test func tellsWhereThePhotoWentOrThatItFailed() throws {
        let feedback = try surface.feedback
        feedback.reducesMotion = { true }
        view.camera.showPhoto(.saved)
        #expect(feedback.message.stringValue == "Saved to Pictures and copied")
        view.camera.showPhoto(.failed)
        #expect(feedback.message.stringValue == "Couldn't take the photo")
        #expect(feedback.toast.alphaValue == 1)
    }

    @Test func doesNotFlashWhenMotionIsReduced() throws {
        let feedback = try surface.feedback
        feedback.reducesMotion = { true }
        feedback.fire()
        #expect(feedback.flash.alphaValue == 0)
    }

    @Test func mirrorsTheSettingOnTheInlineViewToo() throws {
        view.camera.setMirrored(true)
        #expect(try surface.mirror.isOn)
        view.camera.setMirrored(false)
        #expect(try !surface.mirror.isOn)
    }
}
