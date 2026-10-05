import AppKit
import SearchKit

final class SettingsSuggestionCell: NSTableCellView {
    static let titleSize: CGFloat = 13
    static let noteSize: CGFloat = 11
    static let indent: CGFloat = 28
    static let trailing: CGFloat = 8
    static let lineHeight: CGFloat = 17
    static let noteHeight: CGFloat = 14
    static let padding: CGFloat = 5
    static let maxLines = 2
    private static let capsGap: CGFloat = 8
    private static let capsSize: CGFloat = 10
    private static let capsInset: CGFloat = 5
    private static let capsHeight: CGFloat = 16
    private static let capsRadius: CGFloat = 4
    private static let capsFill: CGFloat = 0.1
    private static let selectedCapsFill: CGFloat = 0.22
    private static let selectedDim: CGFloat = 0.78
    private static let lineGap: CGFloat = 1

    private let title = NSTextField(wrappingLabelWithString: "")
    private let note = NSTextField(labelWithString: "")
    private let caps = NSTextField(labelWithString: "")
    private let capsBox = NSView()
    private var suggestion: SettingsSearch.Suggestion?

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet { render() }
    }

    init() {
        super.init(frame: .zero)
        title.maximumNumberOfLines = Self.maxLines
        title.lineBreakMode = .byTruncatingTail
        title.cell?.truncatesLastVisibleLine = true
        note.lineBreakMode = .byTruncatingTail
        caps.font = .systemFont(ofSize: Self.capsSize, weight: .medium)
        capsBox.wantsLayer = true
        capsBox.layer?.cornerRadius = Self.capsRadius
        capsBox.addSubview(caps)
        let lines = NSStackView(views: [title, note])
        lines.orientation = .vertical
        lines.alignment = .leading
        lines.spacing = Self.lineGap
        let row = NSStackView(views: [lines, capsBox])
        row.alignment = .centerY
        row.spacing = Self.capsGap
        row.translatesAutoresizingMaskIntoConstraints = false
        caps.translatesAutoresizingMaskIntoConstraints = false
        lines.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.indent),
            row.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor, constant: -Self.trailing),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
            capsBox.heightAnchor.constraint(equalToConstant: Self.capsHeight),
            caps.leadingAnchor.constraint(equalTo: capsBox.leadingAnchor, constant: Self.capsInset),
            caps.trailingAnchor.constraint(
                equalTo: capsBox.trailingAnchor, constant: -Self.capsInset),
            caps.centerYAnchor.constraint(equalTo: capsBox.centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    static func titleFont(bold: Bool) -> NSFont {
        .systemFont(ofSize: titleSize, weight: bold ? .semibold : .regular)
    }

    static func height(of suggestion: SettingsSearch.Suggestion, width: CGFloat) -> CGFloat {
        let text = NSAttributedString(
            string: suggestion.title.string, attributes: [.font: titleFont(bold: false)])
        let available = width - indent - trailing
        let wide = text.boundingRect(
            with: NSSize(width: available, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin)
        let lines = min(maxLines, max(1, Int((wide.height / lineHeight).rounded())))
        let noteSpace = suggestion.note == nil ? 0 : noteHeight
        return CGFloat(lines) * lineHeight + noteSpace + padding + padding
    }

    func show(_ suggestion: SettingsSearch.Suggestion, keycaps: [String], width: CGFloat) {
        self.suggestion = suggestion
        caps.stringValue = keycaps.joined()
        let titleWidth = NSAttributedString(
            string: suggestion.title.string, attributes: [.font: Self.titleFont(bold: true)]
        ).size().width
        let capsWidth = caps.fittingSize.width + Self.capsInset + Self.capsInset + Self.capsGap
        capsBox.isHidden =
            keycaps.isEmpty || titleWidth + capsWidth > width - Self.indent - Self.trailing
        note.isHidden = suggestion.note == nil
        setAccessibilityLabel(suggestion.spoken)
        render()
    }

    private func render() {
        guard let suggestion else { return }
        let selected = backgroundStyle == .emphasized
        let plain: NSColor = selected ? .white : .labelColor
        let dim: NSColor =
            selected ? .white.withAlphaComponent(Self.selectedDim) : .secondaryLabelColor
        title.attributedStringValue = SidebarText.styled(
            suggestion.title, size: Self.titleSize, color: plain, matchColor: plain,
            weight: .regular)
        if let text = suggestion.note {
            note.attributedStringValue = SidebarText.styled(
                text, size: Self.noteSize, color: dim, matchColor: plain, weight: .regular)
        }
        caps.textColor = plain
        let fill = selected ? Self.selectedCapsFill : Self.capsFill
        effectiveAppearance.performAsCurrentDrawingAppearance {
            capsBox.layer?.backgroundColor =
                (selected ? NSColor.white : .labelColor)
                .withAlphaComponent(fill).cgColor
        }
    }
}

extension SettingsSearch.Suggestion {
    var spoken: String {
        let note = note?.string == place.title ? nil : note?.string
        return [title.string, note, place.page, place.tab].compactMap(\.self)
            .joined(separator: ", ")
    }
}
