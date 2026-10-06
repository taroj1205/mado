public import AppKit

public final class LyricsSpotPicker: NSView {
    private static let padding: CGFloat = 16
    private static let gap: CGFloat = 20
    private static let radius: CGFloat = 10
    private static let titleSize: CGFloat = 13
    private static let detailSize: CGFloat = 12
    private static let textGap: CGFloat = 6
    private static let fadeSeconds = 0.2
    private static let dimmed: CGFloat = 0.5
    private static let offTitle = "Not kept on screen"
    private static let offDetail =
        "Lyrics stay in the launcher. Pick a spot to keep the line on screen once it closes."

    public var onChange: (() -> Void)?
    let map = LyricsSpotMap()
    private let title = NSTextField(labelWithString: "")
    private let detail = NSTextField(wrappingLabelWithString: "")
    let off = NSButton(title: "Turn Off", target: nil, action: nil)
    private let text = NSStackView()
    private let read: () -> LyricsSpot?
    private let write: (LyricsSpot?) -> Void

    override public var wantsUpdateLayer: Bool { true }

    public var isEnabled = true {
        didSet {
            map.isEnabled = isEnabled
            off.isEnabled = isEnabled
            alphaValue = isEnabled ? 1 : Self.dimmed
            unsafe window?.invalidateCursorRects(for: map)
        }
    }

    public init(read: @escaping () -> LyricsSpot?, write: @escaping (LyricsSpot?) -> Void) {
        self.read = read
        self.write = write
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = Self.radius
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1
        title.font = .systemFont(ofSize: Self.titleSize, weight: .semibold)
        detail.font = .systemFont(ofSize: Self.detailSize)
        detail.textColor = .secondaryLabelColor
        detail.isSelectable = false
        off.bezelStyle = .rounded
        off.controlSize = .small
        off.target = self
        off.action = #selector(turnOff)
        map.onPick = { [weak self] spot in self?.commit(spot) }
        text.setViews([title, detail], in: .top)
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = Self.textGap
        text.wantsLayer = true
        arrange()
        setAccessibilityElement(false)
        refresh()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override public func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.quaternarySystemFill.cgColor
            layer?.borderColor = NSColor.separatorColor.cgColor
        }
    }

    override public func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    public func refresh() {
        let spot = read()
        let words = spot.map { ($0.title, $0.detail) } ?? (Self.offTitle, Self.offDetail)
        if title.stringValue != words.0 {
            if !map.reducesMotion() { fade() }
            title.stringValue = words.0
            detail.stringValue = words.1
        }
        off.isHidden = spot == nil
        map.select(spot, animated: unsafe window != nil)
    }

    @objc
    private func turnOff() {
        commit(nil)
    }

    private func commit(_ spot: LyricsSpot?) {
        write(spot)
        refresh()
        onChange?()
    }

    private func fade() {
        let swap = CATransition()
        swap.type = .fade
        swap.duration = Self.fadeSeconds
        text.layer?.add(swap, forKey: "swap")
    }

    private func arrange() {
        for view in [map, text, off] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            map.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.padding),
            map.topAnchor.constraint(equalTo: topAnchor, constant: Self.padding),
            map.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.padding),
            map.widthAnchor.constraint(equalToConstant: LyricsSpotMap.width),
            map.heightAnchor.constraint(equalToConstant: LyricsSpotMap.height),
            text.leadingAnchor.constraint(equalTo: map.trailingAnchor, constant: Self.gap),
            text.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.padding),
            text.topAnchor.constraint(equalTo: map.topAnchor),
            detail.widthAnchor.constraint(equalTo: text.widthAnchor),
            off.leadingAnchor.constraint(equalTo: text.leadingAnchor),
            off.bottomAnchor.constraint(equalTo: map.bottomAnchor),
        ])
    }
}
