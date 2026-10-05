import AppCore
import AppKit

extension SpeechModelSettings {
    private static let symbol = "line.3.horizontal.decrease.circle"
    private static let activeSymbol = "line.3.horizontal.decrease.circle.fill"

    private static func title(_ status: SpeechModelFilter.Status) -> String {
        switch status {
        case .any: "All Models"
        case .downloaded: "Downloaded"
        case .notDownloaded: "Not Downloaded"
        }
    }

    private static func title(_ language: SpeechModelFilter.Language) -> String {
        switch language {
        case .any: "Any Language"
        case .multilingual: "Multilingual"
        case .englishOnly: "English Only"
        }
    }

    private static func title(_ size: SpeechModelFilter.Size) -> String {
        switch size {
        case .any: "Any Size"
        case .under100MB: "Under 100 MB"
        case .under500MB: "Under 500 MB"
        case .under1GB: "Under 1 GB"
        }
    }

    private static func title(_ version: SpeechModelFilter.Version) -> String {
        switch version {
        case .any: "Full Size and Compressed"
        case .fullSize: "Full Size Only"
        case .compressed: "Compressed Only"
        }
    }

    func makeFilterButton() -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: true)
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        button.setAccessibilityLabel("Filters")
        return button
    }

    func refreshFilterButton() {
        guard let button = filterButton else { return }
        let active = filter.activeCount
        let menu = NSMenu()
        menu.autoenablesItems = false
        let title = NSMenuItem(
            title: active == 0 ? "Filters" : "Filters (\(active))", action: nil, keyEquivalent: "")
        title.image = NSImage(
            systemSymbolName: active == 0 ? Self.symbol : Self.activeSymbol,
            accessibilityDescription: nil)
        menu.addItem(title)
        add("Show", \.status, titled: Self.title, to: menu)
        add("Language", \.language, titled: Self.title, to: menu)
        add("Size", \.size, titled: Self.title, to: menu)
        add("Version", \.version, titled: Self.title, to: menu)
        menu.addItem(.separator())
        let clear = NSMenuItem(
            title: "Clear Filters", action: #selector(clearFilters), keyEquivalent: "")
        clear.target = self
        clear.isEnabled = active > 0
        menu.addItem(clear)
        button.menu = menu
    }

    private func add<Value: CaseIterable & Equatable>(
        _ title: String, _ key: WritableKeyPath<SpeechModelFilter, Value>,
        titled: (Value) -> String, to menu: NSMenu
    ) {
        menu.addItem(.sectionHeader(title: title))
        for value in Value.allCases {
            var picked = filter
            picked[keyPath: key] = value
            let item = NSMenuItem(
                title: titled(value), action: #selector(pickFilter), keyEquivalent: "")
            item.target = self
            item.state = filter[keyPath: key] == value ? .on : .off
            item.representedObject = picked
            menu.addItem(item)
        }
    }

    @objc
    private func pickFilter(_ item: NSMenuItem) {
        guard var picked = item.representedObject as? SpeechModelFilter else { return }
        picked.query = filter.query
        filter = picked
        refreshList()
    }
}
