import AppKit

final class WidgetDisc: NSView {
    static let size: CGFloat = 28
    private static let half: CGFloat = 0.5
    private static let edgeWidth: CGFloat = 0.5
    private static let fillAlpha = (dark: 0.18, light: 0.08)
    private static let edgeAlpha = (dark: 0.16, light: 0.07)
    private static let glyphSize: CGFloat = 12
    private static let glyphBox: CGFloat = 18
    private static let playNudge: CGFloat = 1
    private static let fadeSeconds = 0.18

    let glyph = NSImageView()
    private lazy var nudge = glyph.centerXAnchor.constraint(equalTo: centerXAnchor)

    override var wantsUpdateLayer: Bool {
        true
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.size, height: Self.size)
    }

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = Self.size * Self.half
        layer?.borderWidth = Self.edgeWidth
        glyph.wantsLayer = true
        glyph.symbolConfiguration = .init(pointSize: Self.glyphSize, weight: .semibold)
        glyph.contentTintColor = .labelColor
        glyph.translatesAutoresizingMaskIntoConstraints = false
        addSubview(glyph)
        NSLayoutConstraint.activate([
            nudge,
            glyph.centerYAnchor.constraint(equalTo: centerYAnchor),
            glyph.widthAnchor.constraint(equalToConstant: Self.glyphBox),
            glyph.heightAnchor.constraint(equalToConstant: Self.glyphBox),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let dark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let ink = dark ? NSColor.white : .black
            layer?.backgroundColor =
                ink.withAlphaComponent(dark ? Self.fillAlpha.dark : Self.fillAlpha.light).cgColor
            layer?.borderColor =
                ink.withAlphaComponent(dark ? Self.edgeAlpha.dark : Self.edgeAlpha.light).cgColor
        }
    }

    func show(playing: Bool, animated: Bool) {
        let name = playing ? "pause.fill" : "play.fill"
        nudge.constant = playing ? 0 : Self.playNudge
        if animated {
            let fade = CATransition()
            fade.duration = Self.fadeSeconds
            glyph.layer?.add(fade, forKey: "swap")
        }
        glyph.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }
}
