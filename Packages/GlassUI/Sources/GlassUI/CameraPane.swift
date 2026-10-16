public import AppCore
public import AppKit
public import AVFoundation

public final class CameraPane: NSView, CameraScreen {
    private static let inset: CGFloat = 12

    public var onAction: ((CameraWindow.Action) -> Void)?
    public var onSelect: ((CameraDevice) -> Void)?
    public var onMirror: ((Bool) -> Void)?
    public var onCapture: (() -> Bool)?
    public var onPopOut: (() -> Void)?
    private(set) var surface: CameraSurface?

    override init(frame: NSRect) {
        super.init(frame: frame)
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    public func use(_ session: AVCaptureSession) {
        guard surface == nil else { return }
        let made = CameraSurface(session: session, style: .inline)
        made.onAction = { [weak self] in self?.onAction?($0) }
        made.onSelect = { [weak self] in self?.onSelect?($0) }
        made.onMirror = { [weak self] in self?.onMirror?($0) }
        made.onCapture = { [weak self] in self?.onCapture?() ?? false }
        made.onPopOut = { [weak self] in self?.onPopOut?() }
        made.translatesAutoresizingMaskIntoConstraints = false
        addSubview(made)
        NSLayoutConstraint.activate([
            made.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.inset),
            made.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.inset),
            made.topAnchor.constraint(equalTo: topAnchor, constant: Self.inset),
            made.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.inset),
        ])
        surface = made
    }

    public func shoot() {
        surface?.shoot()
    }

    public func setPhase(_ phase: CameraWindow.Phase) {
        surface?.setPhase(phase)
    }

    public func setDevices(_ devices: [CameraDevice], current: String?) {
        surface?.setDevices(devices, current: current)
    }

    public func setMirrored(_ mirrored: Bool) {
        surface?.setMirrored(mirrored)
    }

    public func showPhoto(_ capture: CameraWindow.Capture) {
        surface?.feedback.show(capture)
    }
}
