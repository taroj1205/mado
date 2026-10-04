import AppCore
import AppKit
import ClipboardKit
import GlassUI
import os

@MainActor
final class EmojiPicker: NSObject {
    static let commandID = "emoji.search"
    static let title = "Search Emoji & Symbols"
    static let placeholder = "Search emoji and symbols…"
    static let prefix = ":"
    static let capsule: [LauncherView.CapsuleSlot] = [
        .keyed(LauncherView.Action.secondaryKeys), .primary, .actions,
    ]
    private static let symbol = "face.smiling"
    private static let idPrefix = "emoji.grid."
    private static let recentTitle = "Recently used"
    private static let pasteTitle = "Paste"
    private static let groupSymbols = [
        "Smileys & Emotion": "face.smiling", "People & Body": "hand.raised",
        "Animals & Nature": "leaf", "Food & Drink": "fork.knife", "Travel & Places": "car",
        "Activities": "soccerball", "Objects": "lightbulb", "Symbols": "heart", "Flags": "flag",
    ]

    var onOpen: (() -> Void)?
    var onLoad: (() -> Void)?
    var onUnload: (() -> Void)?
    var onChange: ((EmojiSettings) -> Void)?
    var settings = EmojiSettings() {
        didSet { tonePicker.selectItem(at: Emoji.Tone.allCases.firstIndex(of: settings.tone) ?? 0) }
    }
    private(set) lazy var toneAccessory = makeToneAccessory()

    var tabs: [EmojiGrid.Tab] {
        let recent =
            settings.recent.isEmpty
            ? [] : [EmojiGrid.Tab(title: "Recent", symbol: "clock", section: Self.recentTitle)]
        return recent
            + (catalog?.groups ?? []).map { group in
                EmojiGrid.Tab(
                    title: group.name, symbol: Self.groupSymbols[group.name] ?? "circle",
                    section: group.name)
            }
    }
    private let tonePicker = NSPopUpButton(frame: .zero, pullsDown: false)
    private var catalog: EmojiCatalog?

    static func owns(_ id: String) -> Bool {
        id.hasPrefix(idPrefix)
    }

    private static func character(in id: String) -> String? {
        let rest = id.dropFirst(idPrefix.count)
        return rest.firstIndex(of: ".").map { dot in String(rest[rest.index(after: dot)...]) }
    }

    func query(in text: String) -> String? {
        guard catalog != nil, text.hasPrefix(Self.prefix) else { return nil }
        return String(text.dropFirst(Self.prefix.count))
    }

    func start(context: ModuleContext) {
        context.own(.other, "emoji catalog") { [weak self] in
            self?.catalog = nil
            self?.onUnload?()
        }
        let open = CommandAction(id: "open", title: "Open \(Self.title)") { [weak self] in
            self?.onOpen?()
        }
        do {
            try context.register(
                Command(
                    id: Self.commandID, name: Self.title, icon: Self.symbol, actions: [open],
                    keywords: ["emoji", "symbols", "smiley", "character", "picker"]))
        } catch {
            context.logger.error(
                "Emoji command failed: \(String(describing: error), privacy: .public)")
        }
        context.run("load emoji") { [weak self] in
            let loaded = await Task.detached { EmojiCatalog.bundled() }.value
            guard let self, let loaded, !Task.isCancelled else { return }
            catalog = loaded
            onLoad?()
        }
    }

    private func makeToneAccessory() -> NSView {
        let label = NSTextField(labelWithString: "Skin tone")
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        label.textColor = .secondaryLabelColor
        tonePicker.addItems(withTitles: Emoji.Tone.allCases.map(\.title))
        tonePicker.selectItem(at: Emoji.Tone.allCases.firstIndex(of: settings.tone) ?? 0)
        tonePicker.controlSize = .small
        tonePicker.refusesFirstResponder = true
        tonePicker.target = self
        tonePicker.action = #selector(toneChanged)
        tonePicker.setAccessibilityLabel("Skin tone")
        return NSStackView(views: [label, tonePicker])
    }

    @objc
    private func toneChanged() {
        let tones = Emoji.Tone.allCases
        guard tones.indices.contains(tonePicker.indexOfSelectedItem) else { return }
        settings.tone = tones[tonePicker.indexOfSelectedItem]
        onChange?(settings)
    }

    func sections(for query: String, pastingInto target: PasteTarget?) -> [ResultList.Section] {
        guard let catalog else {
            let notice = ResultList.Notice(title: "Loading emoji…", detail: "")
            return [ResultList.Section(title: "", items: [], notice: notice)]
        }
        let action = target == nil ? "" : Self.pasteTitle
        let recent = settings.recent.compactMap(catalog.emoji)
        var sections =
            recent.isEmpty ? [] : [section(Self.recentTitle, recent, action: action, at: 0)]
        let needle = query.trimmingCharacters(in: .whitespaces)
        if needle.isEmpty {
            for group in catalog.groups {
                sections.append(
                    section(group.name, group.emoji, action: action, at: sections.count))
            }
            return sections
        }
        let found = catalog.search(needle)
        guard !found.isEmpty else {
            let notice = ResultList.Notice(
                title: "No emoji match “\(needle)”",
                detail: "Try another word, like heart or smile.")
            return [ResultList.Section(title: "", items: [], notice: notice)]
        }
        var matching = section("Matching “\(needle)”", found, action: action, at: sections.count)
        matching.selectsFirst = true
        return sections + [matching]
    }

    private func section(
        _ title: String, _ emoji: [Emoji], action: String, at index: Int
    ) -> ResultList.Section {
        ResultList.Section(
            title: title,
            items: emoji.map { emoji in
                var item = ResultList.Item(
                    id: "\(Self.idPrefix)\(index).\(emoji.character)", title: emoji.name,
                    subtitle: emoji.shortcode, kind: "", symbol: "", action: action)
                item.glyph = emoji.toned(settings.tone)
                return item
            })
    }

    func actions(
        for id: String, pastingInto target: PasteTarget?
    ) -> [(action: CommandAction, keys: [String])] {
        guard let character = Self.character(in: id), let emoji = catalog?.emoji(character) else {
            return []
        }
        let glyph = emoji.toned(settings.tone)
        let copy = CommandAction(id: "copy", title: "Copy") { [weak self] in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(glyph, forType: .string)
            self?.use(character)
        }
        guard let target else { return [(copy, LauncherView.Action.secondaryKeys)] }
        let paste = CommandAction(id: "paste", title: Self.pasteTitle) { [weak self] in
            try await target.action(pasting: glyph).perform()
            self?.use(character)
        }
        return [
            (paste, LauncherView.Action.primaryKeys), (copy, LauncherView.Action.secondaryKeys),
        ]
    }

    private func use(_ character: String) {
        settings.use(character)
        onChange?(settings)
    }
}
