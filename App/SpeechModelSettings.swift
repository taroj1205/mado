import AppCore
import AppKit
import os

@MainActor
final class SpeechModelSettings: NSObject {
    final class Download {
        let task: Task<Void, Never>
        var fraction = 0.0
        weak var bar: NSProgressIndicator?
        weak var percent: NSTextField?

        init(task: Task<Void, Never>) {
            self.task = task
        }
    }

    private static let title = "Speech models"

    private let logger = Log.logger("Settings")
    let modules: ModuleManager?
    let store = SpeechModelStore.standard
    var downloads: [String: Download] = [:]
    var filter = SpeechModelFilter()
    weak var searchField: NSSearchField?
    weak var summary: NSStackView?
    weak var list: NSStackView?
    weak var countLabel: NSTextField?
    weak var filterButton: NSPopUpButton?

    var section: SettingsSection {
        let content = makeContent()
        refreshList()
        return SettingsSection(Self.title, content: content)
    }

    init(modules: ModuleManager?) {
        self.modules = modules
    }

    func refreshList() {
        guard let list else { return }
        let inUse = store.model(preferring: DictationSettings.load(from: modules).model)
        let shown = filter.shown(SpeechModel.all, isInstalled: store.isInstalled)
        let box =
            shown.isEmpty
            ? emptyState()
            : SettingsPageController.box(
                shown.map { model in rowView(for: model, inUse: model == inUse) })
        list.setViews([box], in: .top)
        box.widthAnchor.constraint(equalTo: list.widthAnchor).isActive = true
        if let summary {
            let card = summaryCard(inUse: inUse)
            summary.setViews([card], in: .top)
            card.widthAnchor.constraint(equalTo: summary.widthAnchor).isActive = true
        }
        let total = SpeechModel.all.count
        countLabel?.stringValue =
            shown.count == total ? "\(total) models" : "\(shown.count) of \(total)"
        refreshFilterButton()
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

    private func saveModelInUse() {
        var settings = DictationSettings.load(from: modules)
        settings.model = store.model(preferring: settings.model)?.id
        settings.save(to: modules)
    }

    @objc
    func searched(_ field: NSSearchField) {
        filter.query = field.stringValue
        refreshList()
    }

    @objc
    func showAll() {
        let order = filter.order
        filter = SpeechModelFilter()
        filter.order = order
        searchField?.stringValue = ""
        refreshList()
    }

    @objc
    func clearFilters() {
        let query = filter.query
        let order = filter.order
        filter = SpeechModelFilter()
        filter.query = query
        filter.order = order
        refreshList()
    }

    @objc
    func fetch(_ sender: NSButton) {
        guard let model = model(for: sender), downloads[model.id] == nil else { return }
        let task = Task { [weak self, store] in
            do {
                try await store.download(model) { fraction in
                    Task { @MainActor in self?.show(fraction, for: model.id) }
                }
                self?.saveModelInUse()
            } catch  where !Task.isCancelled {
                self?.logger.error(
                    "Downloading \(model.id, privacy: .public) failed: \(error, privacy: .public)")
                NSApp.presentError(error)
            } catch {
                self?.logger.debug("Downloading \(model.id, privacy: .public) was cancelled")
            }
            self?.downloads[model.id] = nil
            self?.refreshList()
        }
        downloads[model.id] = Download(task: task)
        refreshList()
    }

    @objc
    func cancel(_ sender: NSButton) {
        guard let model = model(for: sender) else { return }
        downloads[model.id]?.task.cancel()
    }

    @objc
    func use(_ sender: NSButton) {
        guard let model = model(for: sender) else { return }
        var settings = DictationSettings.load(from: modules)
        settings.model = model.id
        settings.save(to: modules)
        refreshList()
    }

    @objc
    func remove(_ sender: NSButton) {
        guard let model = model(for: sender) else { return }
        do {
            try store.delete(model)
            saveModelInUse()
        } catch {
            logger.error(
                "Deleting \(model.id, privacy: .public) failed: \(error, privacy: .public)")
            sender.presentError(error)
        }
        refreshList()
    }
}
