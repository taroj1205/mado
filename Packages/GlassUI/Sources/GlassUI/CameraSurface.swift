import AppCore
import AppKit
import AVFoundation

final class CameraSurface: NSView {
    static let radius: CGFloat = 22
    private static let inset: CGFloat = 12
    private static let barHeight: CGFloat = 36
    private static let barPadding: CGFloat = 4
    private static let closeSide: CGFloat = 32
    private static let shadeHeight: CGFloat = 96
    private static let fadeSeconds = 0.18
    private static let revealSeconds = 0.4
    private static let pickerHeight: CGFloat = 28
    private static let pickerRadius: CGFloat = 14
    private static let pickerWidth: CGFloat = 220
    private static let gripSide: CGFloat = 32
    private static let half: CGFloat = 0.5

    var onClose: (() -> Void)?
    var onMirror: ((Bool) -> Void)?
    var onSelect: ((CameraDevice) -> Void)?
    var onAction: ((CameraWindow.Action) -> Void)?
    private(set) var phase = CameraWindow.Phase.starting
    private(set) var isHovered = false
    let preview: CameraPreview
    let notice = CameraNotice()
    let picker = CapsuleButton("Camera", keys: [], symbol: "video", height: pickerHeight)
    let mirror = CameraButton(
        symbol: "flip.horizontal", onSymbol: "flip.horizontal.fill", label: "Mirror")
    let dismiss = CameraButton(symbol: "xmark", onSymbol: "xmark", label: "Close camera")
    private(set) var devices: [CameraDevice] = []
    private(set) var current: String?
    private let shade = CameraShade()
    private let grip = CameraGrip()
    private(set) lazy var bar = makeBar()
    private(set) lazy var closer = makeCloser()

    override var mouseDownCanMoveWindow: Bool { true }

    init(session: AVCaptureSession) {
        preview = CameraPreview(session: session)
        super.init(frame: .zero)
        wantsLayer = true
        let clip = NSView()
        clip.wantsLayer = true
        clip.layer?.cornerRadius = Self.radius
        clip.layer?.cornerCurve = .continuous
        clip.layer?.masksToBounds = true
        let border = GlassBorder(radius: Self.radius)
        clip.addSubview(preview)
        pin(preview, to: clip)
        for view in [clip, shade, notice, border, bar, closer, grip] {
            addSubview(view)
        }
        for view in [clip, notice, border] {
            pin(view, to: self)
        }
        arrange()
        connect()
        addTrackingArea(
            NSTrackingArea(
                rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self))
        setPhase(.starting)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func setPhase(_ next: CameraWindow.Phase) {
        let revealing = next == .live && phase != .live
        phase = next
        notice.show(next)
        if next == .live {
            preview.mirror(preview.isMirrored)
            if revealing { reveal() }
        } else {
            preview.alphaValue = 0
        }
        refresh(animated: false)
    }

    func setMirrored(_ mirrored: Bool) {
        mirror.isOn = mirrored
        preview.mirror(mirrored)
    }

    func setDevices(_ next: [CameraDevice], current id: String?) {
        devices = next
        current = id
        let name = next.first { $0.id == id }?.name ?? next.first?.name ?? "Camera"
        picker.label.stringValue = name
        picker.setAccessibilityLabel("Camera: \(name)")
    }

    func setHovered(_ hovered: Bool, animated: Bool) {
        guard hovered != isHovered else { return }
        isHovered = hovered
        refresh(animated: animated)
    }

    override func mouseEntered(with _: NSEvent) {
        setHovered(true, animated: true)
    }

    override func mouseExited(with _: NSEvent) {
        setHovered(false, animated: true)
    }

    private func connect() {
        dismiss.onPress = { [weak self] in self?.onClose?() }
        mirror.onPress = { [weak self] in
            guard let self else { return }
            mirror.isOn.toggle()
            preview.mirror(mirror.isOn)
            onMirror?(mirror.isOn)
        }
        picker.onPress = { [weak self] in self?.chooseCamera() }
        notice.onAction = { [weak self] in self?.onAction?($0) }
    }

    private func arrange() {
        NSLayoutConstraint.activate([
            shade.leadingAnchor.constraint(equalTo: leadingAnchor),
            shade.trailingAnchor.constraint(equalTo: trailingAnchor),
            shade.bottomAnchor.constraint(equalTo: bottomAnchor),
            shade.heightAnchor.constraint(equalToConstant: Self.shadeHeight),
            bar.centerXAnchor.constraint(equalTo: centerXAnchor),
            bar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.inset),
            bar.leadingAnchor.constraint(
                greaterThanOrEqualTo: leadingAnchor, constant: Self.inset),
            bar.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor, constant: -Self.inset),
            closer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.inset),
            closer.topAnchor.constraint(equalTo: topAnchor, constant: Self.inset),
            picker.widthAnchor.constraint(lessThanOrEqualToConstant: Self.pickerWidth),
            grip.trailingAnchor.constraint(equalTo: trailingAnchor),
            grip.bottomAnchor.constraint(equalTo: bottomAnchor),
            grip.widthAnchor.constraint(equalToConstant: Self.gripSide),
            grip.heightAnchor.constraint(equalToConstant: Self.gripSide),
        ])
    }

    private func makeBar() -> GlassView {
        picker.cornerRadius = Self.pickerRadius
        picker.label.lineBreakMode = .byTruncatingTail
        let stack = NSStackView(views: [picker, FloatingCapsule.divider(), mirror])
        stack.spacing = Self.barPadding
        return FloatingCapsule.make(
            stack, leading: Self.barPadding, trailing: Self.barPadding, height: Self.barHeight,
            radius: Self.barHeight * Self.half)
    }

    private func makeCloser() -> GlassView {
        FloatingCapsule.make(
            NSStackView(views: [dismiss]), leading: 0, trailing: 0, height: Self.closeSide,
            radius: Self.closeSide * Self.half)
    }

    private func reveal() {
        preview.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.revealSeconds
            preview.animator().alphaValue = 1
        }
    }

    private func refresh(animated: Bool) {
        let live = phase == .live
        let glow: CGFloat = isHovered && live ? 1 : 0
        let close: CGFloat = isHovered || !live ? 1 : 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = animated ? Self.fadeSeconds : 0
            bar.animator().alphaValue = glow
            shade.animator().alphaValue = glow
            closer.animator().alphaValue = close
        }
    }

    func cameraMenu() -> NSMenu {
        let menu = NSMenu()
        for device in devices {
            let item = NSMenuItem(
                title: device.name, action: #selector(picked(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = device.id
            item.state = device.id == current ? .on : .off
            menu.addItem(item)
        }
        return menu
    }

    private func chooseCamera() {
        cameraMenu().popUp(positioning: nil, at: .zero, in: picker)
    }

    @objc
    private func picked(_ item: NSMenuItem) {
        guard let device = devices.first(where: { $0.id == item.representedObject as? String })
        else { return }
        onSelect?(device)
    }

    private func pin(_ view: NSView, to other: NSView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: other.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: other.trailingAnchor),
            view.topAnchor.constraint(equalTo: other.topAnchor),
            view.bottomAnchor.constraint(equalTo: other.bottomAnchor),
        ])
    }
}
