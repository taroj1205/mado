import AppCore
import AppKit

final class MenuBarAgendaCard: NSView {
    private static let width: CGFloat = 300
    private static let margin: CGFloat = 8
    private static let padding: CGFloat = 10
    private static let spacing: CGFloat = 6
    private static let radius: CGFloat = 12
    private static let fill: CGFloat = 0.06
    private static let buttonHeight: CGFloat = 28
    private static let captionSize: CGFloat = 11.5
    private static let titleSize: CGFloat = 14
    private static let detailSize: CGFloat = 12
    private static let buttonSize: CGFloat = 13
    private static let half: CGFloat = 2

    private let card = NSStackView()
    private let onJoin: () -> Void

    init(event: Agenda.Event, now: Date, joinKeys: String, onJoin: @escaping () -> Void) {
        self.onJoin = onJoin
        super.init(frame: .zero)
        let caption = "Next · \(Agenda.countdown(to: event.start, at: now))"
        card.setViews(
            [
                Self.label(caption, Self.captionSize, .semibold),
                Self.label(event.title, Self.titleSize, .semibold, secondary: false),
                Self.label(Self.detail(of: event), Self.detailSize),
            ], in: .top)
        if event.meeting != nil {
            card.addArrangedSubview(joinButton(keys: joinKeys))
        }
        card.orientation = .vertical
        card.alignment = .leading
        card.spacing = Self.spacing
        card.edgeInsets = NSEdgeInsets(
            top: Self.padding, left: Self.padding, bottom: Self.padding, right: Self.padding)
        card.wantsLayer = true
        card.layer?.cornerRadius = Self.radius
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor, constant: Self.margin / Self.half),
            card.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.margin / Self.half),
            card.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.margin),
            card.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.margin),
            widthAnchor.constraint(equalToConstant: Self.width),
        ])
        layoutSubtreeIfNeeded()
        setFrameSize(fittingSize)
        tint()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func detail(of event: Agenda.Event) -> String {
        let hours = (event.start..<event.end).formatted(.interval.hour().minute())
        return [hours, event.place].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private static func label(
        _ text: String, _ size: CGFloat, _ weight: NSFont.Weight = .regular, secondary: Bool = true
    ) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = secondary ? .secondaryLabelColor : .labelColor
        field.lineBreakMode = .byTruncatingTail
        return field
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        tint()
    }

    private func tint() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            card.layer?.backgroundColor =
                NSColor.labelColor.withAlphaComponent(Self.fill).cgColor
        }
    }

    private func joinButton(keys: String) -> NSButton {
        let icon = NSTextAttachment()
        icon.image = NSImage(systemSymbolName: "video", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: Self.detailSize, weight: .semibold))
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let title = NSMutableAttributedString(attachment: icon)
        title.append(NSAttributedString(string: "  Join  \(keys)"))
        title.addAttributes(
            [
                .font: NSFont.systemFont(ofSize: Self.buttonSize, weight: .semibold),
                .foregroundColor: NSColor.white, .paragraphStyle: style,
            ], range: NSRange(location: 0, length: title.length))
        let button = NSButton(title: "", target: self, action: #selector(joined))
        button.attributedTitle = title
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.systemBlue.cgColor
        button.layer?.cornerRadius = Self.buttonHeight / Self.half
        button.heightAnchor.constraint(equalToConstant: Self.buttonHeight).isActive = true
        button.widthAnchor.constraint(
            equalToConstant: Self.width - Self.half * (Self.margin + Self.padding)
        ).isActive = true
        return button
    }

    @objc
    private func joined() {
        onJoin()
    }
}
