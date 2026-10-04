import AppCore
import AppKit
import ClipboardKit
import GlassUI
import os
import SearchKit
import WindowKit

@MainActor
final class Snippets: NSObject, NSWindowDelegate, Module {
    static let commandID = "clipboard.snippets"
    static let moduleID = "snippets"
    private static let title = "Snippets"
    private static let width: CGFloat = 760
    private static let height: CGFloat = 560
    private static let radius: CGFloat = 20

    let descriptor = ModuleDescriptor(
        id: Snippets.moduleID, name: Snippets.title, enabledByDefault: true)

    private weak var modules: ModuleManager?
    private let editor = SnippetEditor()
    private let expander = SnippetExpander(logger: Log.logger(Snippets.moduleID))
    private lazy var panel = makePanel()
    private var target: PasteTarget?
    private var copyCheck: (@MainActor () -> Void)?

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
        expander.beforeReplacing = { [weak self] in self?.copyCheck?() }
    }

    static func registered(in manager: ModuleManager) throws -> Snippets {
        let snippets = Snippets(modules: manager)
        try manager.register(snippets)
        let open = CommandAction(id: "open", title: "Open \(title)") { [weak snippets] in
            snippets?.open()
        }
        try manager.commands.register(
            Command(
                id: commandID, name: title, icon: "text.alignleft", actions: [open],
                keywords: ["snippets", "text expansion", "keyword", "template"]))
        return snippets
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

    func start(context: ModuleContext) {
        reload()
        guard expander.settings.expands else { return }
        expander.install(in: context)
        context.logger.debug("Started")
    }

    func stop() {
        Log.logger(Self.moduleID).debug("Stopped")
    }

    func checkCopies(with check: (@MainActor () -> Void)?) {
        copyCheck = check
    }

    func reload() {
        let settings = SnippetSettings.load(from: modules)
        expander.settings = settings
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

    private func update(_ change: (inout SnippetSettings) -> Void) throws -> SnippetSettings {
        var settings = SnippetSettings.load(from: modules)
        change(&settings)
        try modules?.setValue(settings, for: SnippetSettings.key)
        reload()
        return settings
    }

    private func failed(_ error: any Error) -> String {
        Log.logger("App").error(
            "Saving \(SnippetSettings.key, privacy: .public) failed: \(error, privacy: .public)")
        reload()
        return error.localizedDescription
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
        do {
            editor.show(Self.entries(try update { $0.save(snippet) }), selecting: snippet.id)
            return nil
        } catch {
            return failed(error)
        }
    }

    private func delete(_ id: String) -> String? {
        do {
            editor.show(Self.entries(try update { $0.remove(id) }), selecting: nil)
            return nil
        } catch {
            return failed(error)
        }
    }

    private func setExpands(_ expands: Bool) -> String? {
        do {
            _ = try update { $0.expands = expands }
            try modules?.restart(Self.moduleID)
            return nil
        } catch {
            return failed(error)
        }
    }

    private func paste(_ values: SnippetEditor.Values) {
        guard let target, !expander.isBusy else {
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
