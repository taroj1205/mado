public import AppKit

@MainActor
public final class DictationPill {
    public enum State: Equatable, Sendable {
        case ready(hint: String)
        case listening(since: ContinuousClock.Instant)
        case failed(String, fix: String?)
    }

    private static let height: CGFloat = 44
    private static let inset: CGFloat = 18
    private static let gap: CGFloat = 10
    private static let bottomGap: CGFloat = 32
    private static let titleSize: CGFloat = 13
    private static let detailSize: CGFloat = 12
    private static let clockSize: CGFloat = 12.5
    private static let symbolSize: CGFloat = 14
    private static let haloSize: CGFloat = 16
    nonisolated private static let dotInset: CGFloat = 4
    nonisolated private static let haloAlpha: CGFloat = 0.25
    private static let half: CGFloat = 0.5
    private static let secondsPerMinute: Int64 = 60
    private static let secondsDigits = 2
    private static let failureSeconds = 4
    private static let recordingDot = NSImage(
        size: NSSize(width: haloSize, height: haloSize), flipped: false
    ) { rect in
        NSColor.systemRed.withAlphaComponent(haloAlpha).setFill()
        NSBezierPath(ovalIn: rect).fill()
        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: rect.insetBy(dx: dotInset, dy: dotInset)).fill()
        return true
    }

    public var onFix: (() -> Void)?
    let panel = OverlayPanel()
    let stack = NSStackView()
    let icon = NSImageView()
    let dot = NSImageView(image: recordingDot)
    let meter = LevelMeter()
    let title = FloatingCapsule.label(weight: .medium, color: .labelColor)
    let detail = NSTextField(labelWithString: "")
    let clock = NSTextField(labelWithString: "")
    let fix = ChipButton()
    public private(set) var state: State?
    var failureDuration: Duration = .seconds(failureSeconds)
    private var dismissal: Task<Void, Never>?

    public init() {
        title.font = .systemFont(ofSize: Self.titleSize, weight: .medium)
        detail.font = .systemFont(ofSize: Self.detailSize)
        detail.textColor = .secondaryLabelColor
        clock.font = .monospacedDigitSystemFont(ofSize: Self.clockSize, weight: .regular)
        clock.textColor = .secondaryLabelColor
        icon.symbolConfiguration = .init(pointSize: Self.symbolSize, weight: .medium)
        icon.setAccessibilityElement(false)
        dot.setAccessibilityElement(false)
        fix.onPress = { [weak self] in
            self?.onFix?()
            self?.hide()
        }
        for view in [icon, dot, meter, title, detail, clock, fix] {
            stack.addArrangedSubview(view)
        }
        stack.spacing = Self.gap
        stack.setAccessibilityElement(true)
        stack.setAccessibilityRole(.group)
        let glass = FloatingCapsule.make(
            stack, leading: Self.inset, trailing: Self.inset, height: Self.height,
            radius: Self.height * Self.half)
        let content = NSView()
        content.addSubview(glass)
        NSLayoutConstraint.activate([
            glass.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            glass.topAnchor.constraint(equalTo: content.topAnchor),
            glass.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        panel.contentView = content
        panel.hasShadow = true
    }

    static func clock(_ elapsed: Duration) -> String {
        let seconds = max(elapsed.components.seconds, 0)
        let minutes = seconds / secondsPerMinute
        let rest = seconds % secondsPerMinute
        return "\(minutes):\(rest.formatted(.number.precision(.integerLength(secondsDigits))))"
    }

    public func show(_ state: State, on screen: NSScreen?) {
        dismissal?.cancel()
        dismissal = nil
        self.state = state
        let visible: [NSView]
        switch state {
        case .ready(let hint):
            show(symbol: "mic", tint: .labelColor)
            title.stringValue = "Ready"
            detail.stringValue = hint
            visible = [icon, title, detail]
            stack.setAccessibilityLabel("Ready, \(hint)")

        case .listening:
            meter.reset()
            clock.stringValue = Self.clock(.zero)
            visible = [dot, meter, clock]
            stack.setAccessibilityLabel("Listening")

        case let .failed(message, fixTitle):
            show(symbol: "exclamationmark.triangle", tint: .systemOrange)
            title.stringValue = message
            fix.title = fixTitle ?? ""
            visible = fixTitle == nil ? [icon, title] : [icon, title, fix]
            stack.setAccessibilityLabel(message)
            dismissal = Task { [weak self, failureDuration] in
                try? await Task.sleep(for: failureDuration)
                guard !Task.isCancelled else { return }
                self?.hide()
            }
        }
        for view in stack.arrangedSubviews {
            view.isHidden = !visible.contains(view)
        }
        panel.ignoresMouseEvents = fix.isHidden
        place(on: screen)
        panel.orderFrontRegardless()
    }

    public func hear(_ level: Double, at now: ContinuousClock.Instant = .now) {
        guard case .listening(let since) = state else { return }
        meter.add(level, at: now)
        let text = Self.clock(since.duration(to: now))
        guard text != clock.stringValue else { return }
        clock.stringValue = text
        resize()
    }

    public func hide() {
        dismissal?.cancel()
        dismissal = nil
        state = nil
        panel.orderOut(nil)
    }

    private func show(symbol: String, tint: NSColor) {
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        icon.contentTintColor = tint
    }

    private func width() -> CGFloat {
        panel.contentView?.layoutSubtreeIfNeeded()
        return (panel.contentView?.fittingSize.width ?? 0).rounded(.up)
    }

    private func place(on screen: NSScreen?) {
        if screen == nil, panel.isVisible {
            resize()
            return
        }
        guard let visible = (screen ?? NSScreen.main)?.visibleFrame else { return }
        let width = width()
        panel.setFrame(
            CGRect(
                x: (visible.midX - width * Self.half).rounded(),
                y: visible.minY + Self.bottomGap, width: width, height: Self.height),
            display: true)
    }

    private func resize() {
        let width = width()
        guard width != panel.frame.width else { return }
        panel.setFrame(
            CGRect(
                x: (panel.frame.midX - width * Self.half).rounded(), y: panel.frame.minY,
                width: width, height: Self.height),
            display: true)
    }
}
