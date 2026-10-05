import AppCore
import AppKit
import GlassUI

extension SpeechModelSettings {
    private static let footnote =
        "Speed and accuracy for Small, Large v3 Turbo and the two Parakeet models come from "
        + "Mado’s own tests. "
        + "The rest are estimated from each model’s size."
    private static let spacing: CGFloat = 8
    private static let lineSpacing: CGFloat = 2
    private static let padding: CGFloat = 12
    private static let rowInset: CGFloat = 10
    private static let searchWidth: CGFloat = 180
    private static let speedWidth: CGFloat = 48
    private static let accuracyWidth: CGFloat = 56
    private static let actionWidth: CGFloat = 104
    private static let percentWidth: CGFloat = 32
    private static let emptyInset: CGFloat = 24
    private static let nameSize: CGFloat = 13
    private static let textSize: CGFloat = 12
    private static let smallSize: CGFloat = 11
    private static let badgeSize: CGFloat = 10
    private static let badgeRadius: CGFloat = 4
    private static let badgeInset: CGFloat = 5
    private static let badgeTint: CGFloat = 0.16
    static let buttonHeight: CGFloat = 26
    private static let deleteSize: CGFloat = 12
    private static let cancelSize: CGFloat = 10

    static func percentText(_ fraction: Double) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0)))
    }

    static func bytes(_ count: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.isAdaptive = false
        return formatter.string(fromByteCount: count)
    }

    private static func text(
        _ string: String, size: CGFloat = textSize, weight: NSFont.Weight = .regular,
        color: NSColor = .secondaryLabelColor
    ) -> NSTextField {
        let label = NSTextField(labelWithString: string)
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        return label
    }

    private static func sized(_ view: NSView, _ width: CGFloat) -> NSView {
        view.widthAnchor.constraint(equalToConstant: width).isActive = true
        return view
    }

    private static func badge(_ title: String) -> NSView {
        let label = text(title, size: badgeSize, weight: .semibold, color: .controlAccentColor)
        let box = NSBox()
        box.boxType = .custom
        box.titlePosition = .noTitle
        box.borderWidth = 0
        box.cornerRadius = badgeRadius
        box.fillColor = .controlAccentColor.withAlphaComponent(badgeTint)
        box.contentViewMargins = NSSize(width: badgeInset, height: 1)
        box.contentView = label
        box.widthAnchor.constraint(
            equalToConstant: label.fittingSize.width + badgeInset + badgeInset
        )
        .isActive = true
        return box
    }

    private static func languages(_ model: SpeechModel) -> String? {
        if model.isEnglishOnly { return nil }
        return model.isJapaneseOnly ? "Japanese only" : "\(model.languages) languages"
    }

    private static func meta(_ model: SpeechModel) -> String {
        [
            bytes(model.size),
            model.memory.map { "uses \(bytes($0)) of memory" },
            languages(model),
        ]
        .compactMap(\.self).joined(separator: " · ")
    }

    func makeContent() -> NSView {
        let search = NSSearchField()
        search.placeholderString = "Search models"
        search.stringValue = filter.query
        search.sendsSearchStringImmediately = true
        search.target = self
        search.action = #selector(searched)
        search.widthAnchor.constraint(equalToConstant: Self.searchWidth).isActive = true
        let count = Self.text("")
        let filters = makeFilterButton()
        searchField = search
        countLabel = count
        filterButton = filters
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let toolbar = NSStackView(views: [search, spacer, count, makeSortButton(), filters])
        toolbar.spacing = Self.spacing
        let card = NSStackView()
        summary = card
        let rows = NSStackView()
        rows.orientation = .vertical
        list = rows
        let note = NSTextField(wrappingLabelWithString: Self.footnote)
        note.font = .systemFont(ofSize: Self.smallSize)
        note.textColor = .secondaryLabelColor
        let content = NSStackView(views: [card, toolbar, header(), rows, note])
        content.orientation = .vertical
        content.spacing = Self.spacing
        content.setCustomSpacing(Self.padding, after: card)
        for part in content.arrangedSubviews {
            part.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
        }
        return content
    }

    private func header() -> NSView {
        let model = Self.text("Model", weight: .semibold)
        model.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let header = NSStackView(views: [
            model,
            Self.sized(Self.text("Speed", weight: .semibold), Self.speedWidth),
            Self.sized(Self.text("Accuracy", weight: .semibold), Self.accuracyWidth),
            Self.sized(NSView(), Self.actionWidth),
        ])
        header.spacing = Self.spacing
        header.distribution = .fill
        header.edgeInsets = NSEdgeInsets(
            top: 0, left: Self.padding, bottom: 0, right: Self.padding)
        return header
    }

    func emptyState() -> NSView {
        let label = Self.text("No models match")
        let reset = NSButton(title: "Show All Models", target: self, action: #selector(showAll))
        let stack = NSStackView(views: [label, reset])
        stack.orientation = .vertical
        stack.edgeInsets = NSEdgeInsets(
            top: Self.emptyInset, left: 0, bottom: Self.emptyInset, right: 0)
        return SettingsPageController.box([stack])
    }

    func rowView(for model: SpeechModel, inUse: Bool) -> NSView {
        let name = Self.text(model.name, size: Self.nameSize, weight: .medium, color: .labelColor)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let badges = model.isRecommended ? [Self.badge("Recommended")] : []
        let title = NSStackView(views: [name] + badges + [spacer])
        title.spacing = Self.badgeInset
        let summary = WrappingLabel(model.summary, size: Self.textSize, color: .secondaryLabelColor)
        let meta = Self.text(Self.meta(model), size: Self.smallSize, color: .tertiaryLabelColor)
        meta.lineBreakMode = .byTruncatingTail
        meta.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let details = NSStackView(views: [title, summary, meta])
        details.orientation = .vertical
        details.alignment = .leading
        details.spacing = Self.lineSpacing
        for line in details.arrangedSubviews {
            line.widthAnchor.constraint(equalTo: details.widthAnchor).isActive = true
        }
        details.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [
            details,
            Self.sized(
                SpeechModelRating(model.speed, named: "Speed", measured: model.isMeasured),
                Self.speedWidth),
            Self.sized(
                SpeechModelRating(model.accuracy, named: "Accuracy", measured: model.isMeasured),
                Self.accuracyWidth),
            Self.sized(action(for: model, inUse: inUse), Self.actionWidth),
        ])
        row.spacing = Self.spacing
        row.distribution = .fill
        row.edgeInsets = NSEdgeInsets(
            top: Self.rowInset, left: Self.padding, bottom: Self.rowInset, right: Self.padding)
        row.heightAnchor.constraint(
            greaterThanOrEqualTo: details.heightAnchor, constant: Self.rowInset + Self.rowInset
        )
        .isActive = true
        row.setAccessibilityElement(true)
        row.setAccessibilityRole(.group)
        row.setAccessibilityLabel(model.name)
        return row
    }

    private func action(for model: SpeechModel, inUse: Bool) -> NSView {
        let views: [NSView]
        if let download = downloads[model.id] {
            views = progress(of: download, for: model)
        } else if !store.isInstalled(model) {
            views = [pill("Download", symbol: "arrow.down.to.line", for: model, #selector(fetch))]
        } else if inUse {
            views = [Self.text("In use", weight: .semibold, color: .systemGreen), delete(model)]
        } else {
            let use = pill("Use", symbol: nil, for: model, #selector(use))
            use.isEnabled = modules != nil
            views = [use, delete(model)]
        }
        let stack = NSStackView()
        stack.setViews(views, in: .trailing)
        stack.spacing = Self.spacing
        return stack
    }

    func progress(of download: Download, for model: SpeechModel) -> [NSView] {
        let bar = NSProgressIndicator()
        bar.style = .bar
        bar.controlSize = .small
        bar.isIndeterminate = false
        bar.maxValue = 1
        bar.doubleValue = download.fraction
        bar.setAccessibilityLabel("Downloading \(model.name)")
        let percent = Self.text(Self.percentText(download.fraction))
        percent.font = .monospacedDigitSystemFont(ofSize: Self.textSize, weight: .regular)
        percent.alignment = .right
        download.bars.add(bar)
        download.percents.add(percent)
        let cancel = symbolButton(
            "xmark", size: Self.cancelSize, label: "Cancel download of \(model.name)",
            for: model, #selector(cancel))
        return [bar, Self.sized(percent, Self.percentWidth), cancel]
    }

    func pill(
        _ title: String, symbol: String?, for model: SpeechModel, _ action: Selector
    ) -> PillButton {
        let button = PillButton(
            title, height: Self.buttonHeight, symbol: symbol, fill: .tertiarySystemFill,
            text: .labelColor)
        button.setAccessibilityLabel("\(title) \(model.name)")
        button.identifier = NSUserInterfaceItemIdentifier(model.id)
        button.target = self
        button.action = action
        return button
    }

    private func delete(_ model: SpeechModel) -> NSButton {
        symbolButton(
            "trash", size: Self.deleteSize, label: "Delete \(model.name)", for: model,
            #selector(remove))
    }

    private func symbolButton(
        _ symbol: String, size: CGFloat, label: String, for model: SpeechModel,
        _ action: Selector
    ) -> NSButton {
        let button = NSButton(
            image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage(),
            target: self, action: action)
        button.isBordered = false
        button.contentTintColor = .secondaryLabelColor
        button.symbolConfiguration = .init(pointSize: size, weight: .medium)
        button.identifier = NSUserInterfaceItemIdentifier(model.id)
        button.setAccessibilityLabel(label)
        return button
    }
}
