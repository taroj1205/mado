public import AppKit

@MainActor
public final class PasteStackHUD {
    public enum RowState: Sendable {
        case next
        case waiting
        case pasted
    }

    public struct Row: Equatable, Sendable {
        public let title: String
        public let state: RowState

        public init(title: String, state: RowState) {
            self.title = title
            self.state = state
        }
    }

    static let width: CGFloat = 300
    static let shownRows = 8
    static let emptyHint = "Copy things to add them here"
    private static let radius: CGFloat = 20
    private static let padding: CGFloat = 10
    private static let gap: CGFloat = 2
    private static let textInset: CGFloat = 6
    private static let textGap: CGFloat = 8
    private static let keyGap: CGFloat = 4
    private static let headerSize: CGFloat = 12
    private static let footerSize: CGFloat = 11.5
    private static let rowHeight: CGFloat = 34
    private static let rowRadius: CGFloat = 10
    private static let rowSpacing: CGFloat = 10
    private static let badgeSize: CGFloat = 20
    private static let titleSize: CGFloat = 13
    private static let detailSize: CGFloat = 11
    private static let pastedAlpha: CGFloat = 0.4
    private static let half: CGFloat = 0.5

    let panel = GlassPanel(kind: .hud, contentRect: .zero, shape: .rounded(radius))
    let content = NSView()
    let count = NSTextField(labelWithString: "")
    let rows = NSStackView()

    public init() {
        count.font = .systemFont(ofSize: Self.headerSize, weight: .semibold)
        count.textColor = .secondaryLabelColor
        let keys = NSStackView(views: ["⌘", "V"].map(FloatingCapsule.keycap))
        keys.spacing = Self.keyGap
        let header = Self.spread(count, keys, top: Self.gap, bottom: Self.textGap)
        let footer = Self.spread(
            Self.secondary("⌘V pastes the next item", size: Self.footerSize),
            Self.secondary("esc clears", size: Self.footerSize), top: Self.textGap,
            bottom: Self.gap)
        rows.orientation = .vertical
        rows.spacing = Self.gap
        let stack = NSStackView(views: [header, rows, footer])
        stack.orientation = .vertical
        stack.spacing = Self.gap
        stack.edgeInsets = NSEdgeInsets(
            top: Self.padding, left: Self.padding, bottom: Self.padding, right: Self.padding)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        var fills = [header, rows, footer].map { view in
            view.widthAnchor.constraint(
                equalTo: stack.widthAnchor, constant: -(Self.padding + Self.padding))
        }
        fills.append(stack.widthAnchor.constraint(equalToConstant: Self.width))
        NSLayoutConstraint.activate(
            fills + [
                stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
                stack.topAnchor.constraint(equalTo: content.topAnchor),
                stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            ])
        stack.setAccessibilityElement(true)
        stack.setAccessibilityRole(.group)
        stack.setAccessibilityLabel("Paste stack")
        panel.glass.contentView = content
        let border = GlassBorder(radius: Self.radius)
        border.frame = panel.glass.container.bounds
        border.autoresizingMask = [.width, .height]
        panel.glass.container.addSubview(border)
    }

    private static func spread(
        _ leading: NSView, _ trailing: NSView, top: CGFloat, bottom: CGFloat
    ) -> NSStackView {
        let line = NSStackView(views: [leading, NSView(), trailing])
        line.edgeInsets = NSEdgeInsets(
            top: top, left: textInset, bottom: bottom, right: textInset)
        return line
    }

    private static func secondary(_ text: String, size: CGFloat) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: size)
        label.textColor = .secondaryLabelColor
        return label
    }

    private static func box(radius: CGFloat, fill: NSColor) -> NSBox {
        let box = NSBox()
        box.boxType = .custom
        box.borderWidth = 0
        box.cornerRadius = radius
        box.fillColor = fill
        box.contentViewMargins = .zero
        return box
    }

    private static func view(for row: Row, number: Int) -> NSView {
        let isNext = row.state == .next
        let digits = NSTextField(labelWithString: number.formatted())
        digits.font = .systemFont(ofSize: detailSize, weight: .bold)
        digits.textColor = isNext ? .white : .secondaryLabelColor
        let badge = box(
            radius: badgeSize * half,
            fill: isNext ? .controlAccentColor : FloatingCapsule.keycapFill)
        digits.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(digits)
        let title = NSTextField(labelWithString: row.title)
        title.font = .systemFont(ofSize: titleSize)
        title.lineBreakMode = .byTruncatingTail
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        title.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let note =
            switch row.state {
            case .next: "next"
            case .waiting: ""
            case .pasted: "pasted"
            }
        let detail = secondary(note, size: detailSize)
        let view = line([badge, title, detail], fill: isNext ? ResultRowView.fill : .clear)
        view.alphaValue = row.state == .pasted ? pastedAlpha : 1
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: badgeSize),
            badge.heightAnchor.constraint(equalToConstant: badgeSize),
            digits.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            digits.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
        ])
        return view
    }

    private static func line(_ views: [NSView], fill: NSColor) -> NSBox {
        let line = NSStackView(views: views)
        line.distribution = .fill
        line.spacing = rowSpacing
        line.translatesAutoresizingMaskIntoConstraints = false
        let view = box(radius: rowRadius, fill: fill)
        view.addSubview(line)
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: rowHeight),
            line.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: rowSpacing),
            line.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -rowSpacing),
            line.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        return view
    }

    public func show(_ shown: [Row], left: Int, placing place: (CGSize) -> CGRect) {
        count.stringValue = "PASTE STACK · \(left.formatted()) LEFT"
        rows.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let views =
            shown.isEmpty
            ? [Self.line([Self.secondary(Self.emptyHint, size: Self.titleSize)], fill: .clear)]
            : shown.prefix(Self.shownRows).enumerated().map { Self.view(for: $1, number: $0 + 1) }
        for view in views {
            rows.addArrangedSubview(view)
            view.widthAnchor.constraint(equalTo: rows.widthAnchor).isActive = true
        }
        panel.setFrame(place(content.fittingSize), display: true)
        panel.orderFrontRegardless()
    }

    public func hide() {
        panel.orderOut(nil)
    }
}
