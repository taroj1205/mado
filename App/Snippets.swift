import AppCore
import AppKit
import ClipboardKit
import GlassUI
import os
import SearchKit
import WindowKit

@MainActor
final class Snippets: NSObject, NSWindowDelegate {
    static let commandID = "clipboard.snippets"
    private static let title = "Snippets"
    private static let width: CGFloat = 760
    private static let height: CGFloat = 560
    private static let radius: CGFloat = 20

    private weak var modules: ModuleManager?
    private let editor = SnippetEditor()
    private lazy var panel = makePanel()
    private var expander: SnippetExpander?
    private var target: PasteTarget?

    init(modules: ModuleManager?) {
        self.modules = modules
        super.init()
        editor.fillInToken = SnippetTemplate.fieldToken
        editor.tokens = { SnippetTemplate.tokenRanges(in: $0) }
        editor.onSave = { [weak self] id, values in self?.save(values, as: id) }
        editor.onDelete = { [weak self] in self?.delete($0) }
        editor.onPaste = { [weak self] in self?.paste($0) }
        editor.onExpandChange = { [weak self] in self?.setExpands($0) }
        editor.onClose = { [weak self] in self?.close() }
    }

    private static func name(of app: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app) else {
            return app
        }
        return AppIndex.name(of: url)
    }

    private static func entries(_ settings: SnippetSettings) -> [SnippetEditor.Entry] {
        settings.snippets
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .map { snippet in
                SnippetEditor.Entry(
                    id: snippet.id,
                    values: .init(name: snippet.name, keyword: snippet.keyword, text: snippet.text))
            }
    }

    func start(with context: ModuleContext) {
        let made = SnippetExpander(logger: context.logger)
        expander = made
        reload()
        made.install(in: context)
        context.own(.other, "snippets") { [weak self] in self?.stop() }
        let open = CommandAction(id: "open", title: "Open \(Self.title)") { [weak self] in
            self?.open()
        }
        do {
            try context.register(
                Command(
                    id: Self.commandID, name: Self.title, icon: "text.alignleft", actions: [open],
                    keywords: ["snippets", "text expansion", "keyword", "template"]))
        } catch {
            context.logger.error(
                "Snippets command failed: \(String(describing: error), privacy: .public)")
        }
    }

    func checkCopies(with check: @escaping @MainActor () -> Void) {
        expander?.beforeReplacing = check
    }

    func reload() {
        let settings = SnippetSettings.load(from: modules)
        expander?.settings = settings
        editor.showExpansion(settings.expands, offIn: settings.appsWithoutExpansion.map(Self.name))
    }

    func windowDidResignKey(_: Notification) {
        close()
    }

    private func open() {
        target = .frontmost()
        let screen = LauncherScreen.load(from: modules).screen ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            panel.setFrame(
                ScreenGeometry.centeredFrame(
                    of: CGSize(width: Self.width, height: Self.height), in: visible), display: false
            )
        }
        let settings = SnippetSettings.load(from: modules)
        editor.show(Self.entries(settings), selecting: nil)
        reload()
        panel.makeKeyAndOrderFront(nil)
        editor.begin()
    }

    private func close() {
        panel.orderOut(nil)
    }

    private func stop() {
        close()
        expander = nil
    }

    private func update(_ change: (inout SnippetSettings) -> Void) -> SnippetSettings {
        var settings = SnippetSettings.load(from: modules)
        change(&settings)
        settings.save(to: modules)
        reload()
        return settings
    }

    private func save(_ values: SnippetEditor.Values, as id: String?) -> String? {
        let current = SnippetSettings.load(from: modules)
        if let owner = current.snippet(overlapping: values.keyword, besides: id) {
            return owner.keyword == values.keyword
                ? "“\(values.keyword)” already expands \(owner.name)."
                : "“\(values.keyword)” overlaps “\(owner.keyword)”, which expands \(owner.name)."
        }
        let snippet = Snippet(
            name: values.name, keyword: values.keyword, text: values.text,
            id: id ?? UUID().uuidString)
        let saved = update { $0.save(snippet) }
        editor.show(Self.entries(saved), selecting: snippet.id)
        return nil
    }

    private func delete(_ id: String) {
        editor.show(Self.entries(update { $0.remove(id) }), selecting: nil)
    }

    private func setExpands(_ expands: Bool) {
        _ = update { $0.expands = expands }
    }

    private func paste(_ values: SnippetEditor.Values) {
        guard let target, let expander, !expander.isBusy else {
            NSSound.beep()
            return
        }
        close()
        let snippet = Snippet(name: values.name, keyword: values.keyword, text: values.text)
        Task { await expander.insert(snippet, into: target) }
    }

    private func makePanel() -> GlassPanel {
        let made = GlassPanel(
            kind: .panel,
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: Self.height),
            shape: .rounded(Self.radius))
        made.glass.contentView = editor
        made.delegate = self
        return made
    }
}
