public import AppKit

@MainActor
public final class DictationPill: NSObject {
    public enum Problem: Equatable, Sendable {
        case notAllowed
        case unavailable

        var message: String {
            switch self {
            case .notAllowed: "Microphone not allowed"
            case .unavailable: "Microphone not available"
            }
        }
    }

    enum State: Equatable {
        case ready
        case listening
        case failed(Problem)
    }

    static let readyTitle = "Ready"
    static let readyHint = "hold right ⌥ to talk"
    static let fixTitle = "Open Settings"
    private static let height: CGFloat = 44
    private static let inset: CGFloat = 18
    private static let spacing: CGFloat = 10
    private static let bottomGap: CGFloat = 32
    private static let symbolSize: CGFloat = 16
    private static let titleSize: CGFloat = 13
    private static let detailSize: CGFloat = 12
    private static let timeSize: CGFloat = 12.5
    private static let half: CGFloat = 0.5

    public var onFix: ((Problem) -> Void)?

    let panel = OverlayPanel()
    let stack = NSStackView()
    let icon = NSImageView()
    let title = FloatingCapsule.label(weight: .medium, color: .labelColor)
    let detail = NSTextField(labelWithString: readyHint)
    let dot = RecordingDot()
    let meter = DictationMeter()
    let time = NSTextField(labelWithString: "")
    lazy var fix = DictationFixButton(Self.fixTitle, target: self, action: #selector(pressFix))
    private(set) var state: State?
    private var visibleFrame: CGRect?

    public var isFailed: Bool {
        if case .failed = state { true } else { false }
    }

    override public init() {
        super.init()
        icon.symbolConfiguration = .init(pointSize: Self.symbolSize, weight: .regular)
        title.font = .systemFont(ofSize: Self.titleSize, weight: .medium)
        detail.font = .systemFont(ofSize: Self.detailSize)
        detail.textColor = .secondaryLabelColor
        time.font = .monospacedDigitSystemFont(ofSize: Self.timeSize, weight: .regular)
        time.textColor = .secondaryLabelColor
        stack.spacing = Self.spacing
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
        content.setAccessibilityElement(true)
        content.setAccessibilityRole(.group)
        panel.contentView = content
        panel.hasShadow = true
    }

    static func timeText(_ elapsed: Duration) -> String {
        elapsed.formatted(
            .time(pattern: .minuteSecond(padMinuteToLength: 1, roundFractionalSeconds: .towardZero))
        )
    }

    public func showReady(on screen: NSScreen) {
        visibleFrame = screen.visibleFrame
        meter.reset()
        show(.ready)
    }

    public func listen(level: Float, elapsed: Duration) {
        meter.push(level)
        time.stringValue = Self.timeText(elapsed)
        show(.listening)
    }

    public func fail(_ problem: Problem) {
        show(.failed(problem))
    }

    public func hide() {
        panel.orderOut(nil)
        state = nil
    }

    private func show(_ next: State) {
        if next != state {
            state = next
            render(next)
        }
        panel.contentView?.setAccessibilityLabel(accessibilityText(next))
        place()
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    private func render(_ next: State) {
        switch next {
        case .ready:
            icon.image = NSImage(systemSymbolName: "mic", accessibilityDescription: nil)
            icon.contentTintColor = .labelColor
            title.stringValue = Self.readyTitle
            stack.setViews([icon, title, detail], in: .leading)

        case .listening:
            stack.setViews([dot, meter, time], in: .leading)

        case .failed(let problem):
            icon.image = NSImage(
                systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)
            icon.contentTintColor = .systemOrange
            title.stringValue = problem.message
            stack.setViews([icon, title, fix], in: .leading)
            unsafe NSAccessibility.post(
                element: panel, notification: .announcementRequested,
                userInfo: [.announcement: problem.message])
        }
        panel.ignoresMouseEvents = !isFailed
    }

    private func accessibilityText(_ state: State) -> String {
        switch state {
        case .ready: "Dictation ready, \(Self.readyHint)"
        case .listening: "Listening, \(time.stringValue)"
        case .failed(let problem): problem.message
        }
    }

    private func place() {
        guard let visibleFrame, let content = panel.contentView else { return }
        let width = content.fittingSize.width
        let frame = CGRect(
            x: (visibleFrame.midX - width * Self.half).rounded(),
            y: visibleFrame.minY + Self.bottomGap, width: width, height: Self.height)
        if frame != panel.frame {
            panel.setFrame(frame, display: true)
        }
    }

    @objc
    private func pressFix() {
        guard case .failed(let problem) = state else { return }
        hide()
        onFix?(problem)
    }
}
