import AppKit
import Carbon.HIToolbox

final class LoupeKeyCap: NSView {
    static let side: CGFloat = 60
    private static let radius: CGFloat = 13
    private static let lip: CGFloat = 4
    private static let legendInset: CGFloat = 8
    private static let letterSize: CGFloat = 24
    private static let glyphSize: CGFloat = 11
    private static let promptSize: CGFloat = 10.5
    private static let lineWidth: CGFloat = 1
    private static let recordingLine: CGFloat = 2
    private static let recordingFill: CGFloat = 0.16
    private static let half: CGFloat = 0.5
    private static let faceAlpha = (dark: 0.14, light: 0.95)
    private static let lipAlpha = (dark: 0.4, light: 0.16)
    private static let edgeAlpha = (dark: 0.16, light: 0.12)
    private static let face = SheetForm.adaptive(
        dark: .white.withAlphaComponent(faceAlpha.dark),
        light: .white.withAlphaComponent(faceAlpha.light))
    private static let underside = SheetForm.adaptive(
        dark: .black.withAlphaComponent(lipAlpha.dark),
        light: .black.withAlphaComponent(lipAlpha.light))
    private static let edge = SheetForm.adaptive(
        dark: .white.withAlphaComponent(edgeAlpha.dark),
        light: .black.withAlphaComponent(edgeAlpha.light))

    let direction: LoupeKeys.Direction
    var onKey: ((Int) -> Void)?
    var letter = "" {
        didSet { render() }
    }

    private(set) var isRecording = false {
        didSet { render() }
    }

    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }
    override var isFlipped: Bool { true }
    override var focusRingMaskBounds: NSRect { faceRect }

    private var faceRect: CGRect {
        CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height - Self.lip)
    }

    init(_ direction: LoupeKeys.Direction) {
        self.direction = direction
        super.init(frame: CGRect(x: 0, y: 0, width: Self.side, height: Self.side))
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.side),
            heightAnchor.constraint(equalToConstant: Self.side),
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        render()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with _: NSEvent) {
        record()
    }

    override func accessibilityPerformPress() -> Bool {
        record()
        return true
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording, unsafe window?.firstResponder === self else {
            return super.performKeyEquivalent(with: event)
        }
        keyDown(with: event)
        return true
    }

    override func keyDown(with event: NSEvent) {
        let key = Int(event.keyCode)
        guard isRecording else {
            if [kVK_Space, kVK_Return].contains(key) {
                record()
            } else {
                super.keyDown(with: event)
            }
            return
        }
        isRecording = false
        if key != kVK_Escape {
            onKey?(key)
        }
        unsafe window?.makeFirstResponder(nil)
    }

    override func drawFocusRingMask() {
        NSBezierPath(roundedRect: faceRect, xRadius: Self.radius, yRadius: Self.radius).fill()
    }

    override func draw(_: NSRect) {
        let rect = faceRect
        Self.underside.setFill()
        NSBezierPath(
            roundedRect: rect.offsetBy(dx: 0, dy: Self.lip), xRadius: Self.radius,
            yRadius: Self.radius
        ).fill()
        let top = NSBezierPath(roundedRect: rect, xRadius: Self.radius, yRadius: Self.radius)
        Self.face.setFill()
        top.fill()
        if isRecording {
            NSColor.controlAccentColor.withAlphaComponent(Self.recordingFill).setFill()
            top.fill()
        }
        let line = isRecording ? Self.recordingLine : Self.lineWidth
        (isRecording ? NSColor.controlAccentColor : Self.edge).setStroke()
        let outline = NSBezierPath(
            roundedRect: rect.insetBy(dx: line * Self.half, dy: line * Self.half),
            xRadius: Self.radius, yRadius: Self.radius)
        outline.lineWidth = line
        outline.stroke()
        drawLegends(in: rect)
    }

    private func drawLegends(in rect: CGRect) {
        let centred = NSMutableParagraphStyle()
        centred.alignment = .center
        if isRecording {
            let prompt = NSAttributedString(
                string: "Press\na key",
                attributes: [
                    .font: NSFont.systemFont(ofSize: Self.promptSize, weight: .medium),
                    .foregroundColor: NSColor.controlAccentColor, .paragraphStyle: centred,
                ])
            let size = prompt.size()
            prompt.draw(
                in: CGRect(
                    x: 0, y: (rect.height - size.height) * Self.half, width: rect.width,
                    height: size.height))
            return
        }
        if letter != direction.glyph {
            NSAttributedString(
                string: direction.glyph,
                attributes: [
                    .font: NSFont.systemFont(ofSize: Self.glyphSize, weight: .medium),
                    .foregroundColor: NSColor.tertiaryLabelColor,
                ]
            ).draw(at: CGPoint(x: Self.legendInset, y: Self.legendInset * Self.half))
        }
        let name = NSAttributedString(
            string: letter,
            attributes: [
                .font: NSFont.systemFont(ofSize: Self.letterSize, weight: .semibold),
                .foregroundColor: NSColor.labelColor, .paragraphStyle: centred,
            ])
        let height = name.size().height
        name.draw(
            in: CGRect(
                x: 0, y: rect.height - height - Self.legendInset * Self.half, width: rect.width,
                height: height))
    }

    private func record() {
        unsafe window?.makeFirstResponder(self)
        isRecording = true
    }

    private func render() {
        needsDisplay = true
        setAccessibilityLabel("\(direction.title): \(letter)")
        setAccessibilityHelp(
            isRecording ? "Press the key to use" : "Click, then press the key you want")
    }
}
