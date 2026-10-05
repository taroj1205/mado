import AppCore
import AppKit
import GlassUI

extension SpeechModelSettings {
    private static let titleSize: CGFloat = 13
    private static let bodySize: CGFloat = 12
    private static let iconSize: CGFloat = 22
    private static let iconWidth: CGFloat = 28
    private static let cardInset: CGFloat = 14
    private static let cardSpacing: CGFloat = 12
    private static let lineSpacing: CGFloat = 3

    private static func emptyBody(_ recommended: SpeechModel?) -> String {
        let start = recommended.map { " \($0.name) is the best start for Japanese and English." }
        return "Dictation needs a speech model on this Mac." + (start ?? "")
    }

    private static func body(_ string: String, color: NSColor) -> NSTextField {
        WrappingLabel(string, size: bodySize, color: color)
    }

    private static func icon(_ symbol: String) -> NSView {
        let image = NSImageView(
            image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage())
        image.symbolConfiguration = .init(pointSize: iconSize, weight: .regular)
        image.contentTintColor = .controlAccentColor
        image.widthAnchor.constraint(equalToConstant: iconWidth).isActive = true
        return image
    }

    func summaryCard(inUse: SpeechModel?) -> NSView {
        let recommended = SpeechModel.all.first(where: \.isRecommended)
        let title = NSTextField(
            labelWithString: inUse.map { "Using \($0.name)" } ?? "No speech model yet")
        title.font = .systemFont(ofSize: Self.titleSize, weight: .semibold)
        var lines: [NSView] = [
            title,
            Self.body(inUse?.summary ?? Self.emptyBody(recommended), color: .secondaryLabelColor),
        ]
        var views: [NSView] = [Self.icon(inUse == nil ? "arrow.down.circle" : "waveform")]
        if let recommended, inUse != recommended, downloads[recommended.id] == nil {
            if inUse != nil {
                lines.append(
                    Self.body(
                        "Tip: \(recommended.name) is more accurate, especially in Japanese.",
                        color: .controlAccentColor))
            }
            views.append(cardButton(for: recommended))
        }
        let text = NSStackView(views: lines)
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = Self.lineSpacing
        for line in lines {
            line.widthAnchor.constraint(equalTo: text.widthAnchor).isActive = true
        }
        text.setContentHuggingPriority(.defaultLow, for: .horizontal)
        views.insert(text, at: 1)
        let stack = NSStackView(views: views)
        stack.spacing = Self.cardSpacing
        stack.alignment = .centerY
        stack.distribution = .fill
        stack.edgeInsets = NSEdgeInsets(
            top: Self.cardInset, left: Self.cardInset, bottom: Self.cardInset,
            right: Self.cardInset)
        stack.heightAnchor.constraint(
            greaterThanOrEqualTo: text.heightAnchor, constant: Self.cardInset + Self.cardInset
        )
        .isActive = true
        return SettingsPageController.box([stack])
    }

    private func cardButton(for model: SpeechModel) -> NSView {
        let installed = store.isInstalled(model)
        let title = installed ? "Use \(model.name)" : "Download · \(Self.bytes(model.size))"
        let button = PillButton(
            title, height: Self.buttonHeight, symbol: installed ? nil : "arrow.down.to.line",
            fill: .controlAccentColor, text: .white)
        button.setAccessibilityLabel(
            installed ? "Use \(model.name)" : "Download recommended model \(model.name)")
        button.identifier = NSUserInterfaceItemIdentifier(model.id)
        button.target = self
        button.action = installed ? #selector(use) : #selector(fetch)
        button.isEnabled = !installed || modules != nil
        return button
    }
}
