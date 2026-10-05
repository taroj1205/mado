public import AppKit

@MainActor
public final class TextCaptureCard {
    public enum Result: Equatable, Sendable {
        case copied(text: String, language: String?)
        case nothingFound
    }

    static let width: CGFloat = 430
    static let shownLines = 6
    private static let radius: CGFloat = 24
    private static let padding: CGFloat = 16
    private static let spacing: CGFloat = 12
    private static let boxPaddingX: CGFloat = 14
    private static let boxPaddingY: CGFloat = 12
    private static let inset = padding + boxPaddingX
    private static let boxRadius: CGFloat = 14
    private static let iconSize: CGFloat = 14
    private static let iconGap: CGFloat = 8
    private static let titleSize: CGFloat = 14
    private static let noteSize: CGFloat = 12
    private static let hintSize: CGFloat = 11.5
    private static let lineGap: CGFloat = 6
    private static let textSize: CGFloat = 12.5
    private static let boxAlpha = (dark: 0.22, light: 0.06)
    private static let boxBorderAlpha = 0.06
    private static let boxFill = NSColor(name: nil) { appearance in
        .black.withAlphaComponent(
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? boxAlpha.dark : boxAlpha.light)
    }

    private static let boxBorder = NSColor.white.withAlphaComponent(boxBorderAlpha)
    private static let textStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineGap
        return style
    }()

    let panel = GlassPanel(kind: .hud, contentRect: .zero, shape: .rounded(radius))
    let content = NSView()
    let title = NSTextField(labelWithString: "")
    let note = NSTextField(labelWithString: "")
    let text = NSTextField(wrappingLabelWithString: "")
    let box = NSBox()
    let hint = NSTextField(labelWithString: "")
    let stack = NSStackView()

    public init() {
        title.font = .systemFont(ofSize: Self.titleSize, weight: .semibold)
        note.font = .systemFont(ofSize: Self.noteSize)
        hint.font = .systemFont(ofSize: Self.hintSize)
        for secondary in [note, hint] {
            secondary.textColor = .secondaryLabelColor
        }
        text.font = .monospacedSystemFont(ofSize: Self.textSize, weight: .regular)
        text.maximumNumberOfLines = Self.shownLines
        text.cell?.truncatesLastVisibleLine = true
        text.isSelectable = false
        text.preferredMaxLayoutWidth = Self.width - Self.inset - Self.inset
        fillBox()
        stack.setViews([header(), box, hint], in: .top)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.spacing
        stack.edgeInsets = NSEdgeInsets(
            top: Self.padding, left: Self.padding, bottom: Self.padding, right: Self.padding)
        stack.setAccessibilityElement(true)
        stack.setAccessibilityRole(.group)
        pin(stack, in: content)
        panel.glass.contentView = content
        let border = GlassBorder(radius: Self.radius)
        border.frame = panel.glass.container.bounds
        border.autoresizingMask = [.width, .height]
        panel.glass.container.addSubview(border)
    }

    static func note(for result: Result) -> String {
        guard case .copied(_, let language) = result else { return "" }
        let name = language.flatMap { Locale.current.localizedString(forLanguageCode: $0) }
        return name.map { "\($0) · on device" } ?? "On device"
    }

    private func fillBox() {
        box.boxType = .custom
        box.borderWidth = 1
        box.borderColor = Self.boxBorder
        box.cornerRadius = Self.boxRadius
        box.fillColor = Self.boxFill
        box.contentViewMargins = .zero
        text.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(text)
        NSLayoutConstraint.activate([
            text.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: Self.boxPaddingX),
            text.trailingAnchor.constraint(
                equalTo: box.trailingAnchor, constant: -Self.boxPaddingX),
            text.topAnchor.constraint(equalTo: box.topAnchor, constant: Self.boxPaddingY),
            text.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -Self.boxPaddingY),
        ])
    }

    private func pin(_ stack: NSStackView, in content: NSView) {
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        var fills = stack.arrangedSubviews.map { view in
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
    }

    private func header() -> NSView {
        let icon = NSImageView(
            image: NSImage(systemSymbolName: "crop", accessibilityDescription: nil) ?? NSImage())
        icon.symbolConfiguration = NSImage.SymbolConfiguration(
            pointSize: Self.iconSize, weight: .semibold)
        icon.contentTintColor = .controlAccentColor
        let left = NSStackView(views: [icon, title])
        left.spacing = Self.iconGap
        let line = NSStackView(views: [left, NSView(), note])
        line.distribution = .fill
        return line
    }

    public func show(_ result: Result, placing place: (CGSize) -> CGRect) {
        switch result {
        case .copied(let captured, _):
            title.stringValue = "Text copied"
            text.attributedStringValue = NSAttributedString(
                string: captured,
                attributes: [
                    .font: text.font
                        ?? .monospacedSystemFont(ofSize: Self.textSize, weight: .regular),
                    .foregroundColor: NSColor.labelColor, .paragraphStyle: Self.textStyle,
                ])
            hint.stringValue = "The text is already on your clipboard"
            box.isHidden = false

        case .nothingFound:
            title.stringValue = "No text found"
            hint.stringValue = "Nothing was copied · try a larger or sharper area"
            box.isHidden = true
        }
        note.stringValue = Self.note(for: result)
        stack.setAccessibilityLabel(
            ([title.stringValue] + (box.isHidden ? [] : [text.stringValue])).joined(separator: ": ")
        )
        panel.setFrame(place(content.fittingSize), display: true)
        panel.orderFrontRegardless()
    }

    public func hide() {
        panel.orderOut(nil)
    }
}
