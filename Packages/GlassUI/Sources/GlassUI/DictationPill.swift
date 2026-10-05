public import AppKit

@MainActor
public final class DictationPill: NSObject {
    public enum State: Equatable, Sendable {
        case ready(hint: String)
        case listening(since: ContinuousClock.Instant)
        case transcribing(model: String)
        case failed(String, fix: String?)
    }

    private static let height: CGFloat = 44
    private static let inset: CGFloat = 18
    private static let gap: CGFloat = 10
    private static let bottomGap: CGFloat = 32
    private static let overshoot: CGFloat = 16
    private static let crossFade: CFTimeInterval = 0.12
    private static let slowestFrameRate: Double = 30
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
    let canvas = NSView()
    let holder: NSView
    let glass: GlassView
    let stack = NSStackView()
    let icon = NSImageView()
    let spinner = Spinner()
    let dot = NSImageView(image: recordingDot)
    let meter = LevelMeter()
    let title = FloatingCapsule.label(weight: .medium, color: .labelColor)
    let detail = NSTextField(labelWithString: "")
    let clock = NSTextField(labelWithString: "")
    let fix = ChipButton()
    public private(set) var state: State?
    var failureDuration: Duration = .seconds(failureSeconds)
    var reducesMotion = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    private(set) var shape = LiquidShape(height: height)
    private var dismissal: Task<Void, Never>?
    private var link: CADisplayLink?
    private var stepped: CFTimeInterval?

    override public init() {
        let clip = NSView()
        holder = clip
        glass = FloatingCapsule.glass(clip, radius: Self.height * Self.half)
        super.init()
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
        spinner.setAccessibilityElement(false)
        for view in [icon, spinner, dot, meter, title, detail, clock, fix] {
            stack.addView(view, in: .center)
        }
        stack.spacing = Self.gap
        stack.edgeInsets = NSEdgeInsets(top: 0, left: Self.inset, bottom: 0, right: Self.inset)
        stack.wantsLayer = true
        stack.setAccessibilityElement(true)
        stack.setAccessibilityRole(.group)
        holder.wantsLayer = true
        holder.layer?.masksToBounds = true
        holder.layer?.cornerCurve = .continuous
        holder.addSubview(stack)
        canvas.addSubview(glass)
        panel.contentView = canvas
        panel.hasShadow = true
        panel.alphaValue = 0
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
        let visible = fill(for: state)
        if panel.isVisible {
            let fade = CATransition()
            fade.type = .fade
            fade.duration = Self.crossFade
            stack.layer?.add(fade, forKey: kCATransition)
        }
        for view in stack.arrangedSubviews {
            view.isHidden = !visible.contains(view)
        }
        panel.ignoresMouseEvents = fix.isHidden
        morph(on: screen)
        panel.orderFrontRegardless()
    }

    private func fill(for state: State) -> [NSView] {
        switch state {
        case .ready(let hint):
            show(symbol: "mic", tint: .labelColor)
            title.stringValue = "Ready"
            detail.stringValue = hint
            stack.setAccessibilityLabel("Ready, \(hint)")
            return [icon, title, detail]

        case .listening:
            meter.reset()
            clock.stringValue = Self.clock(.zero)
            stack.setAccessibilityLabel("Listening")
            return [dot, meter, clock]

        case .transcribing(let model):
            title.stringValue = "Transcribing…"
            detail.stringValue = "\(model) · on device"
            stack.setAccessibilityLabel("Transcribing, \(model) on device")
            return [spinner, title, detail]

        case let .failed(message, fixTitle):
            show(symbol: "exclamationmark.triangle", tint: .systemOrange)
            title.stringValue = message
            fix.title = fixTitle ?? ""
            stack.setAccessibilityLabel(message)
            dismissal = Task { [weak self, failureDuration] in
                try? await Task.sleep(for: failureDuration)
                guard !Task.isCancelled else { return }
                self?.hide()
            }
            return fixTitle == nil ? [icon, title] : [icon, title, fix]
        }
    }

    public func hear(_ level: Double, at now: ContinuousClock.Instant = .now) {
        guard case .listening(let since) = state else { return }
        meter.add(level, at: now)
        let text = Self.clock(since.duration(to: now))
        guard text != clock.stringValue else { return }
        clock.stringValue = text
        morph(on: nil)
    }

    public func hide() {
        dismissal?.cancel()
        dismissal = nil
        state = nil
        panel.ignoresMouseEvents = true
        guard panel.isVisible else { return }
        shape.hide(animated: !reducesMotion())
        run()
    }

    func advance(by seconds: Double) {
        shape.advance(by: seconds)
        apply()
        guard shape.isSettled else { return }
        link?.invalidate()
        link = nil
        stepped = nil
        if !shape.isShown {
            panel.orderOut(nil)
        }
    }

    private func show(symbol: String, tint: NSColor) {
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        icon.contentTintColor = tint
    }

    private func morph(on screen: NSScreen?) {
        let width = stack.fittingSize.width.rounded(.up)
        place(on: screen, fitting: width)
        shape.show(width: width, animated: !reducesMotion())
        run()
    }

    private func place(on screen: NSScreen?, fitting width: CGFloat) {
        let current = panel.isVisible ? panel.frame : nil
        let wide = max(current?.width ?? 0, width + Self.overshoot + Self.overshoot)
        let middle: CGFloat
        let bottom: CGFloat
        if let current, screen == nil {
            middle = current.midX
            bottom = current.minY
        } else {
            guard let visible = (screen ?? NSScreen.main)?.visibleFrame else { return }
            middle = visible.midX
            bottom = visible.minY + Self.bottomGap - Self.overshoot
        }
        let frame = CGRect(
            x: (middle - wide * Self.half).rounded(), y: bottom, width: wide,
            height: Self.height + Self.overshoot + Self.overshoot)
        guard frame != panel.frame else { return }
        panel.setFrame(frame, display: false)
    }

    private func run() {
        apply()
        guard !shape.isSettled, link == nil else { return }
        let started = canvas.displayLink(target: self, selector: #selector(step))
        started.add(to: .main, forMode: .common)
        link = started
    }

    private func apply() {
        let size = shape.size
        let bounds = canvas.bounds
        glass.frame = CGRect(
            x: (bounds.width - size.width) * Self.half,
            y: (bounds.height - size.height) * Self.half,
            width: size.width, height: size.height)
        holder.layer?.cornerRadius = min(size.width, size.height) * Self.half
        stack.frame = CGRect(
            x: (size.width - bounds.width) * Self.half, y: (size.height - Self.height) * Self.half,
            width: bounds.width, height: Self.height)
        stack.alphaValue = shape.contentAlpha
        panel.alphaValue = shape.alpha
        panel.invalidateShadow()
    }

    @objc private func step(_ link: CADisplayLink) {
        let now = link.targetTimestamp
        advance(by: min(now - (stepped ?? link.timestamp), 1 / Self.slowestFrameRate))
        stepped = now
    }
}
