import AppKit
import ClipboardKit
import GlassUI
import WindowKit

@MainActor
final class SnippetFillIn: NSObject, NSWindowDelegate {
    private static let radius: CGFloat = 22
    private static let gap: CGFloat = 8

    private let form = FillInForm()
    private lazy var panel = makePanel()
    private var finish: ((Result<[String: String], CancellationError>) -> Void)?

    private static func appKitRect(_ quartz: CGRect) -> NSRect {
        let primary = NSScreen.screens.first?.frame ?? .zero
        return ScreenGeometry.appKitRect(fromQuartz: quartz, primary: primary)
    }

    func ask(
        _ snippet: Snippet, _ template: SnippetTemplate, under caret: CGRect?
    ) async throws(CancellationError) -> [String: String] {
        close()
        return try await withCheckedContinuation { continuation in
            finish = { continuation.resume(returning: $0) }
            show(snippet, template, under: caret)
        }.get()
    }

    func close() {
        done(.failure(CancellationError()))
    }

    func windowDidResignKey(_: Notification) {
        close()
    }

    private func show(_ snippet: Snippet, _ template: SnippetTemplate, under caret: CGRect?) {
        form.preview = { fields in
            let clipboard = NSPasteboard.general.string(forType: .string) ?? ""
            let expansion = template.expand(.now(fields: fields, clipboard: clipboard))
            return FillInForm.Preview(text: expansion.text, values: expansion.fieldRanges)
        }
        form.onInsert = { [weak self] values in self?.done(.success(values)) }
        form.onCancel = { [weak self] in self?.close() }
        form.show(
            name: snippet.name, keyword: snippet.keyword,
            fields: template.fields.map { FillInForm.Field(name: $0.name, options: $0.options) })
        let anchor =
            caret.map(Self.appKitRect) ?? NSRect(origin: NSEvent.mouseLocation, size: .zero)
        let screen =
            NSScreen.screens.first { $0.frame.intersects(anchor.insetBy(dx: -1, dy: -1)) }
            ?? NSScreen.main
        panel.setFrame(
            ScreenGeometry.frame(
                of: form.fittingSize, below: anchor, gap: Self.gap,
                in: screen?.visibleFrame ?? anchor),
            display: false)
        panel.makeKeyAndOrderFront(nil)
        form.focus()
    }

    private func done(_ result: Result<[String: String], CancellationError>) {
        guard let finish else { return }
        self.finish = nil
        panel.orderOut(nil)
        finish(result)
    }

    private func makePanel() -> GlassPanel {
        let made = GlassPanel(kind: .panel, contentRect: .zero, shape: .rounded(Self.radius))
        made.glass.contentView = form
        made.delegate = self
        return made
    }
}
