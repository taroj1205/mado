import AppCore
import AppKit
import GlassUI
import os

@MainActor
final class SpeechModelSettings: NSObject {
    private final class Download {
        let task: Task<Void, Never>
        var fraction = 0.0
        weak var bar: NSProgressIndicator?
        weak var percent: NSTextField?

        init(task: Task<Void, Never>) {
            self.task = task
        }
    }

    private static let title = "Speech models — all run on this Mac"
    private static let spacing: CGFloat = 8
    private static let padding: CGFloat = 12
    private static let speedWidth: CGFloat = 48
    private static let accuracyWidth: CGFloat = 56
    private static let languagesWidth: CGFloat = 76
    private static let actionWidth: CGFloat = 104
    private static let percentWidth: CGFloat = 32
    private static let textSize: CGFloat = 12
    private static let buttonHeight: CGFloat = 26
    private static let deleteSize: CGFloat = 12
    private static let cancelSize: CGFloat = 10
    private static let named = ["EN", "JA"]

    private let logger = Log.logger("Settings")
    private let modules: ModuleManager?
    private let store = SpeechModelStore.standard
    private var downloads: [String: Download] = [:]
    var onChange: (() -> Void)?

    var section: SettingsSection {
        let current = store.model(preferring: DictationSettings.load(from: modules).model)
        return SettingsSection(
            Self.title, above: header(),
            SpeechModel.all.map { row(for: $0, inUse: $0 == current) })
    }

    init(modules: ModuleManager?) {
        self.modules = modules
    }

    private static func text(
        _ string: String, weight: NSFont.Weight = .regular, color: NSColor = .secondaryLabelColor
    ) -> NSTextField {
        let label = NSTextField(labelWithString: string)
        label.font = .systemFont(ofSize: textSize, weight: weight)
        label.textColor = color
        return label
    }

    private static func sized(_ view: NSView, _ width: CGFloat) -> NSView {
        view.widthAnchor.constraint(equalToConstant: width).isActive = true
        return view
    }

    private static func percentText(_ fraction: Double) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0)))
    }

    private func header() -> NSView {
        let model = Self.text("Model", weight: .semibold)
        model.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let header = NSStackView(views: [
            model,
            Self.sized(Self.text("Speed", weight: .semibold), Self.speedWidth),
            Self.sized(Self.text("Accuracy", weight: .semibold), Self.accuracyWidth),
            Self.sized(Self.text("Languages", weight: .semibold), Self.languagesWidth),
            Self.sized(NSView(), Self.actionWidth),
        ])
        header.spacing = Self.spacing
        header.distribution = .fill
        header.edgeInsets = NSEdgeInsets(
            top: 0, left: Self.padding, bottom: 0, right: Self.padding)
        return header
    }

    private func row(for model: SpeechModel, inUse: Bool) -> SettingsSection.Row {
        let languages = (Self.named + ["+\(model.languages - Self.named.count)"])
            .joined(separator: " · ")
        let control = NSStackView(views: [
            Self.sized(SpeechModelRating(model.speed, named: "Speed"), Self.speedWidth),
            Self.sized(SpeechModelRating(model.accuracy, named: "Accuracy"), Self.accuracyWidth),
            Self.sized(Self.text(languages), Self.languagesWidth),
            Self.sized(action(for: model, inUse: inUse), Self.actionWidth),
        ])
        control.spacing = Self.spacing
        control.setHuggingPriority(.defaultHigh, for: .horizontal)
        let size = ByteCountFormatter()
        size.countStyle = .file
        size.isAdaptive = false
        let detail = ([size.string(fromByteCount: model.size)] + [model.note].compactMap(\.self))
            .joined(separator: " · ")
        return SettingsSection.Row(model.name, control, example: nil) { detail }
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

    private func progress(of download: Download, for model: SpeechModel) -> [NSView] {
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
        download.bar = bar
        download.percent = percent
        let cancel = symbolButton(
            "xmark", size: Self.cancelSize, label: "Cancel download of \(model.name)",
            for: model, #selector(cancel))
        return [bar, Self.sized(percent, Self.percentWidth), cancel]
    }

    private func pill(
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

    private func model(for sender: NSButton) -> SpeechModel? {
        SpeechModel.all.first { $0.id == sender.identifier?.rawValue }
    }

    private func show(_ fraction: Double, for id: String) {
        guard let download = downloads[id], fraction > download.fraction else { return }
        download.fraction = fraction
        download.bar?.doubleValue = fraction
        download.percent?.stringValue = Self.percentText(fraction)
    }

    @objc
    private func fetch(_ sender: NSButton) {
        guard let model = model(for: sender), downloads[model.id] == nil else { return }
        let task = Task { [weak self, store] in
            do {
                try await store.download(model) { fraction in
                    Task { @MainActor in self?.show(fraction, for: model.id) }
                }
            } catch  where !Task.isCancelled {
                self?.logger.error(
                    "Downloading \(model.id, privacy: .public) failed: \(error, privacy: .public)")
                NSApp.presentError(error)
            } catch {
                self?.logger.debug("Downloading \(model.id, privacy: .public) was cancelled")
            }
            self?.downloads[model.id] = nil
            self?.onChange?()
        }
        downloads[model.id] = Download(task: task)
        onChange?()
    }

    @objc
    private func cancel(_ sender: NSButton) {
        guard let model = model(for: sender) else { return }
        downloads[model.id]?.task.cancel()
    }

    @objc
    private func use(_ sender: NSButton) {
        guard let model = model(for: sender) else { return }
        var settings = DictationSettings.load(from: modules)
        settings.model = model.id
        settings.save(to: modules)
        onChange?()
    }

    @objc
    private func remove(_ sender: NSButton) {
        guard let model = model(for: sender) else { return }
        do {
            try store.delete(model)
            var settings = DictationSettings.load(from: modules)
            if settings.model == model.id {
                settings.model = nil
                settings.save(to: modules)
            }
        } catch {
            logger.error(
                "Deleting \(model.id, privacy: .public) failed: \(error, privacy: .public)")
            sender.presentError(error)
        }
        onChange?()
    }
}
