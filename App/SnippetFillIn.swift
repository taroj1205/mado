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

    func ask(
        _ snippet: Snippet, _ template: SnippetTemplate, values: SnippetTemplate.Values,
        under caret: CGRect?
    ) async throws(CancellationError) -> [String: String] {
        close()
        return try await withCheckedContinuation { continuation in
            finish = { continuation.resume(returning: $0) }
            show(snippet, template, values: values, under: caret)
        }.get()
    }

    func close() {
        done(.failure(CancellationError()))
    }

    func windowDidResignKey(_: Notification) {
        close()
    }

    private func show(
        _ snippet: Snippet, _ template: SnippetTemplate, values: SnippetTemplate.Values,
        under caret: CGRect?
    ) {
        form.preview = { fields in
            var shown = values
            shown.fields = fields
            let expansion = template.expand(shown, scalars: FillInForm.previewScalars)
            return FillInForm.Preview(text: expansion.text, values: expansion.fieldRanges)
        }
        form.onInsert = { [weak self] fields in self?.done(.success(fields)) }
        form.onCancel = { [weak self] in self?.close() }
        form.show(
            name: snippet.name, keyword: snippet.keyword,
            fields: template.fields.map { FillInForm.Field(name: $0.name, options: $0.options) })
        let (anchor, screen) = CaretAnchor.find(caret)
        form.maxHeight = screen?.visibleFrame.height
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
