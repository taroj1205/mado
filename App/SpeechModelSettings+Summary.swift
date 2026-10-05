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
    private static let actionWidth: CGFloat = 200

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

    private static func cardText(
        inUse: SpeechModel?, recommended: SpeechModel?, advantage: String?
    ) -> NSView {
        let title = NSTextField(
            labelWithString: inUse.map { "Using \($0.name)" } ?? "No speech model yet")
        title.font = .systemFont(ofSize: titleSize, weight: .semibold)
        var lines: [NSView] = [
            title, body(inUse?.summary ?? emptyBody(recommended), color: .secondaryLabelColor),
        ]
        if let recommended, let advantage {
            lines.append(
                body("Tip: \(recommended.name) is \(advantage).", color: .controlAccentColor))
        }
        let text = NSStackView(views: lines)
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = lineSpacing
        for line in lines {
            line.widthAnchor.constraint(equalTo: text.widthAnchor).isActive = true
        }
        text.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return text
    }

    func summaryCard(inUse: SpeechModel?) -> NSView {
        let recommended = SpeechModel.all.first(where: \.isRecommended)
        let advantage = recommended.flatMap { model in inUse.flatMap(model.advantage) }
        let text = Self.cardText(inUse: inUse, recommended: recommended, advantage: advantage)
        var views: [NSView] = [Self.icon(inUse == nil ? "arrow.down.circle" : "waveform"), text]
        if let recommended, inUse == nil || advantage != nil {
            views.append(cardAction(for: recommended))
        }
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

    private func cardAction(for model: SpeechModel) -> NSView {
        let views =
            downloads[model.id].map { progress(of: $0, for: model) } ?? [cardButton(for: model)]
        let action = NSStackView()
        action.setViews(views, in: .trailing)
        action.widthAnchor.constraint(equalToConstant: Self.actionWidth).isActive = true
        return action
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
