import AppCore
import AppKit
import GlassUI
import SearchKit

@MainActor
final class SettingsFinder {
    struct Shown {
        let page: String
        let tab: String
        let sections: [SettingsSection]
    }

    private static let otherWords: [String: [String]] = [
        "Launcher hotkey": ["shortcut"],
        "Launch at login": ["startup", "login item"],
        "Show on": ["display", "monitor", "screen"],
        "Keep last query": ["remember", "reopen"],
        "Units": ["conversion"],
        "Currency": ["exchange", "money"],
        "Colours": ["colors", "hex"],
        "Dictionary": ["thesaurus", "define"],
        "Location": ["weather", "city"],
        "Keep items for": ["retention", "history length"],
        "Maximum items": ["limit"],
        "Gap between windows": ["padding", "margin", "spacing"],
        "Maximise": ["maximize", "full screen"],
        "Tap the trackpad when the choice changes": ["haptics"],
        "Tap the trackpad as the selection moves": ["haptics"],
        "Next input source": ["language", "IME"],
    ]
    private static let separator = "\u{1F}"

    private let context: SettingsPage.Context
    private let shown: () -> [Shown]
    private var history: SettingsSearch
    private var entries: [SettingsSearch.Entry] = []
    private var places: [SettingsSearch.Place] = []
    private var keys: [String: [String]] = [:]
    private var indexed = false

    var recent: [SettingsSearch.Suggestion] {
        indexIfNeeded()
        return history.recentSuggestions(in: entries)
    }

    init(context: SettingsPage.Context, shown: @escaping () -> [Shown]) {
        self.context = context
        self.shown = shown
        history = SettingsSearch.load(from: context.modules)
    }

    static func id(page: String, tab: String?, section: String?, key: String) -> String {
        [page, tab ?? "", section ?? "", key].joined(separator: separator)
    }

    static func moduleID(page: String, name: String) -> String {
        id(page: page, tab: nil, section: nil, key: name)
    }

    func invalidate() {
        indexed = false
    }

    func groups(for query: String) -> [SettingsSearch.Group] {
        indexIfNeeded()
        return history.groups(for: query, in: entries, places: places, at: .now)
    }

    func keycaps(for entry: String) -> [String] {
        keys[entry] ?? []
    }

    func visit(_ entry: String) {
        history.visit(entry, at: .now)
        history.save(to: context.modules)
    }

    func forget(_ entry: String) {
        history.forget(entry)
        history.save(to: context.modules)
    }

    func clearRecent() {
        history.clearRecent()
        history.save(to: context.modules)
    }

    private func indexIfNeeded() {
        guard !indexed else { return }
        indexed = true
        entries = []
        places = []
        keys = [:]
        let live = shown()
        for page in SettingsPage.all {
            let place = SettingsSearch.Place(page: page.title, tab: nil)
            places.append(place)
            if let module = page.module {
                let id = Self.moduleID(page: page.title, name: module.name)
                entries.append(.init(id: id, place: place, section: nil, label: module.name))
            }
            for tab in page.tabs {
                index(tab, of: page, live: live)
            }
        }
    }

    private func index(_ tab: SettingsPage.Tab, of page: SettingsPage, live: [Shown]) {
        let built = live.first { $0.page == page.title && $0.tab == tab.title }?.sections
        guard let sections = built ?? tab.sections?(context) else { return }
        let tabTitle = page.tabs.count > 1 ? tab.title : nil
        let place = SettingsSearch.Place(page: page.title, tab: tabTitle)
        if tabTitle != nil {
            places.append(place)
        }
        for section in sections {
            for row in section.rows {
                let id = Self.id(
                    page: page.title, tab: tabTitle, section: section.title, key: row.key)
                let keycaps =
                    row.control.firstVisible(HotKeyButton.self)?.keycaps
                    ?? row.control.firstVisible(TriggerButton.self)?.keycaps
                entries.append(
                    .init(
                        id: id, place: place, section: section.title, label: row.label,
                        keywords: Self.otherWords[row.key] ?? [],
                        choices: row.control.firstVisible(SettingsPopUp.self)?.choiceTitles ?? [],
                        isHotkey: keycaps != nil))
                keys[id] = keycaps
            }
        }
    }
}
