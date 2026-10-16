import AppCore
import AppKit
import AVFoundation
import Testing

@testable import GlassUI

@MainActor
@Suite struct CameraWindowTests {
    private let window = CameraWindow(session: AVCaptureSession())
    private let builtIn = CameraDevice(id: "built-in", name: "FaceTime HD Camera")
    private let phone = CameraDevice(id: "phone", name: "iPhone Camera")

    private func buttons(in view: NSView) -> [PillButton] {
        view.subviews.flatMap { ($0 as? PillButton).map { [$0] } ?? buttons(in: $0) }
    }

    @Test func offersSettingsWhenTheCameraIsOff() throws {
        var actions: [CameraWindow.Action] = []
        window.onAction = { actions.append($0) }
        window.setPhase(.denied)
        let notice = window.surface.notice
        #expect(!notice.isHidden)
        #expect(notice.content?.title == "Camera access is off")
        let button = try #require(buttons(in: notice).first)
        button.performClick(nil)
        #expect(actions == [.openSettings])
    }

    @Test func offersAnotherTryWhenTheCameraWillNotOpen() throws {
        var actions: [CameraWindow.Action] = []
        window.onAction = { actions.append($0) }
        window.setPhase(.failed)
        let button = try #require(buttons(in: window.surface.notice).first)
        #expect(button.title == "Try Again")
        button.performClick(nil)
        #expect(actions == [.retry])
    }

    @Test func saysSoWhenThereIsNoCameraAndOffersNothing() {
        window.setPhase(.noCamera)
        #expect(window.surface.notice.content?.title == "No camera found")
        #expect(buttons(in: window.surface.notice).isEmpty)
    }

    @Test func showsOnlyTheNoticeBeforeTheCameraIsLive() {
        window.setPhase(.starting)
        #expect(window.surface.notice.content == nil)
        #expect(!window.surface.notice.isHidden)
        #expect(window.surface.preview.alphaValue == 0)
        window.setPhase(.live)
        #expect(window.surface.notice.isHidden)
    }

    @Test func revealsTheControlsOnlyWhileThePointerIsOverALiveCamera() {
        let surface = window.surface
        surface.setHovered(true, animated: false)
        window.setPhase(.denied)
        #expect(surface.closer.alphaValue == 1)
        #expect(surface.bar.alphaValue == 0)
        window.setPhase(.live)
        #expect(surface.bar.alphaValue == 1)
        surface.setHovered(false, animated: false)
        #expect(surface.bar.alphaValue == 0)
        #expect(surface.closer.alphaValue == 0)
    }

    @Test func closesFromTheCloseButton() {
        var closed = 0
        window.onClose = { closed += 1 }
        window.surface.dismiss.performClick(nil)
        #expect(closed == 1)
    }

    @Test func theMirrorButtonTellsAssistiveTechnologyWhetherItIsOn() {
        let mirror = window.surface.mirror
        #expect(mirror.accessibilityRole() == .checkBox)
        #expect(mirror.accessibilityValue() as? Bool == false)
        window.surface.setMirrored(true)
        #expect(mirror.accessibilityValue() as? Bool == true)
        #expect(window.surface.dismiss.accessibilityRole() != .checkBox)
    }

    @Test func flipsTheMirrorAndReportsIt() {
        var flips: [Bool] = []
        window.onMirror = { flips.append($0) }
        window.surface.setMirrored(true)
        window.surface.mirror.performClick(nil)
        window.surface.mirror.performClick(nil)
        #expect(flips == [false, true])
        #expect(window.surface.mirror.isOn)
    }

    @Test func listsTheCamerasAndMarksTheOneInUse() {
        var picked: [CameraDevice] = []
        window.onSelect = { picked.append($0) }
        window.setDevices([builtIn, phone], current: "phone")
        #expect(window.surface.picker.label.stringValue == "iPhone Camera")
        let menu = window.surface.cameraMenu()
        #expect(menu.items.map(\.title) == ["FaceTime HD Camera", "iPhone Camera"])
        #expect(menu.items.map(\.state) == [.off, .on])
        menu.performActionForItem(at: 0)
        #expect(picked == [builtIn])
    }

    @Test func refitsToANewVideoShapeKeepingTheTopLeft() {
        window.panel.setFrame(CGRect(x: 100, y: 500, width: 360, height: 203), display: false)
        window.fit(to: CGSize(width: 1_440, height: 1_080))
        #expect(window.panel.frame == CGRect(x: 100, y: 433, width: 360, height: 270))
    }
}
