public import AppCore
import AppKit
public import AVFoundation

@MainActor
public final class CameraWindow: CameraScreen {
    public enum Phase: Equatable, Sendable {
        case starting
        case live
        case denied
        case noCamera
        case failed
    }

    public enum Action: Equatable, Sendable {
        case openSettings
        case retry
    }

    public enum Capture: Equatable, Sendable {
        case saved
        case failed
    }

    private static let fadeInSeconds = 0.26
    private static let fadeOutSeconds = 0.16
    private static let settled: CGFloat = 0.94
    private static let half: CGFloat = 0.5

    public var onAction: ((Action) -> Void)?
    public var onClose: (() -> Void)?
    public var onSelect: ((CameraDevice) -> Void)?
    public var onMirror: ((Bool) -> Void)?
    public var onCapture: (() -> Void)?
    public var onFrame: ((CGRect) -> Void)?
    public private(set) var isShown = false
    var reducesMotion = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    var areas = {
        ([NSScreen.main].compactMap(\.self) + NSScreen.screens).map(\.visibleFrame)
    }
    var pointer = { NSEvent.mouseLocation }
    let panel = CameraPanel()
    let surface: CameraSurface
    private var hiding = 0

    public init(session: AVCaptureSession) {
        surface = CameraSurface(session: session, style: .window)
        let glass = GlassView(shape: .rounded(CameraSurface.radius))
        glass.contentView = surface
        panel.contentView = glass
        surface.onClose = { [weak self] in self?.onClose?() }
        surface.onMirror = { [weak self] in self?.onMirror?($0) }
        surface.onSelect = { [weak self] in self?.onSelect?($0) }
        surface.onAction = { [weak self] in self?.onAction?($0) }
        surface.onCapture = { [weak self] in self?.onCapture?() }
    }

    public func show(saved: CGRect?, mirrored: Bool) {
        hiding += 1
        surface.setMirrored(mirrored)
        guard !isShown else {
            panel.orderFrontRegardless()
            return
        }
        let target = CameraGeometry.frame(saved: saved, areas: areas())
        let moves = !reducesMotion()
        panel.alphaValue = 0
        panel.setFrame(moves ? settle(target) : target, display: false)
        surface.setHovered(target.contains(pointer()), animated: false)
        panel.orderFrontRegardless()
        isShown = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeInSeconds
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            if moves { panel.animator().setFrame(target, display: true) }
        }
    }

    public func hide() {
        guard isShown else { return }
        isShown = false
        onFrame?(panel.frame)
        hiding += 1
        let token = hiding
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeOutSeconds
            panel.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated { [weak self] in
                guard let self, hiding == token else { return }
                panel.orderOut(nil)
            }
        }
    }

    public func setPhase(_ phase: Phase) {
        surface.setPhase(phase)
    }

    public func setDevices(_ devices: [CameraDevice], current: String?) {
        surface.setDevices(devices, current: current)
    }

    public func setMirrored(_ mirrored: Bool) {
        surface.setMirrored(mirrored)
    }

    public func showPhoto(_ capture: Capture) {
        surface.feedback.show(capture)
    }

    public func fit(to video: CGSize) {
        let aspect = CameraGeometry.aspect(of: video)
        guard abs(CameraGeometry.aspect(of: panel.frame.size) - aspect) > CameraGeometry.sameShape
        else { return }
        panel.setFrame(
            CameraGeometry.refit(panel.frame, aspect: aspect, areas: areas()), display: true,
            animate: isShown && !reducesMotion())
    }

    private func settle(_ frame: CGRect) -> CGRect {
        frame.insetBy(
            dx: frame.width * (1 - Self.settled) * Self.half,
            dy: frame.height * (1 - Self.settled) * Self.half)
    }
}
