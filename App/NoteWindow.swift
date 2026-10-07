import AppCore
import AppKit
import os

@MainActor
final class NoteWindow: NSObject, NSWindowDelegate, NSTextViewDelegate {
    private final class Panel: NSPanel {
        var onClose: (() -> Void)?

        override var canBecomeKey: Bool { true }

        override func performClose(_: Any?) {
            onClose?()
        }

        override func validateMenuItem(_ item: NSMenuItem) -> Bool {
            item.action == #selector(performClose) || super.validateMenuItem(item)
        }
    }

    private static let dotSize: CGFloat = 10
    private static let dotRadius: CGFloat = 5
    private static let dotAlpha: CGFloat = 0.25
    private static let dotMargin: CGFloat = 6
    private static let saveMilliseconds = 400
    private static let saveDelay = Duration.milliseconds(saveMilliseconds)

    private let logger = Log.logger("Notes")
    private let panel: Panel
    private let textView: NSTextView
    private let save: (Note) throws -> Void
    private let closed: (Note.ID) -> Void
    private var pending: Task<Void, Never>?
    private var isDirty = false
    private var isStored: Bool
    private(set) var note: Note

    init(
        note: Note, isStored: Bool, save: @escaping (Note) throws -> Void,
        closed: @escaping (Note.ID) -> Void
    ) {
        self.note = note
        self.isStored = isStored
        self.save = save
        self.closed = closed
        let scroll = NSTextView.scrollableTextView()
        textView = scroll.documentView as? NSTextView ?? NSTextView()
        panel = Panel(
            contentRect: note.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        super.init()
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.onClose = { [weak self] in self?.close() }
        panel.contentView = makeContent(around: scroll)
        configure(textView)
        restyle()
    }

    private static func dot() -> NSImage {
        let side = NSSize(width: NoteStyle.barHeight - dotMargin, height: NoteStyle.barHeight)
        return NSImage(size: side, flipped: false) { rect in
            NSColor.black.withAlphaComponent(dotAlpha).setFill()
            let spot = NSRect(
                x: rect.midX - dotRadius, y: rect.midY - dotRadius,
                width: dotSize, height: dotSize)
            NSBezierPath(ovalIn: spot).fill()
            return true
        }
    }

    func show(focusing: Bool) {
        if focusing {
            NSApp.activate()
            panel.makeKeyAndOrderFront(nil)
            panel.makeFirstResponder(textView)
        } else {
            panel.orderFront(nil)
        }
    }

    func hide() {
        flush()
        panel.orderOut(nil)
    }

    @discardableResult
    func flush() -> Bool {
        pending?.cancel()
        pending = nil
        guard isDirty else { return true }
        do {
            try save(note)
            isDirty = false
            isStored = true
            return true
        } catch {
            logger.error("Saving a note failed: \(error, privacy: .public)")
            return false
        }
    }

    func textDidChange(_: Notification) {
        restyle()
        note.text = textView.string
        changed()
    }

    func textViewDidChangeSelection(_: Notification) {
        refreshTypingAttributes()
    }

    func windowDidMove(_: Notification) {
        note.frame = panel.frame
        changed()
    }

    private func close() {
        note.isOpen = false
        isDirty = isDirty || isStored || !note.text.isEmpty
        guard flush() else {
            note.isOpen = true
            return
        }
        panel.orderOut(nil)
        closed(note.id)
    }

    private func changed() {
        note.modified = .now
        isDirty = true
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: Self.saveDelay)
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    private func restyle() {
        if let storage = unsafe textView.textStorage {
            NoteStyle.restyle(storage)
        }
        refreshTypingAttributes()
    }

    private func refreshTypingAttributes() {
        textView.typingAttributes = NoteStyle.typingAttributes(
            in: textView.string, caret: textView.selectedRange().location)
    }

    private func configure(_ textView: NSTextView) {
        textView.delegate = self
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.insertionPointColor = NoteStyle.ink
        textView.textContainerInset = NoteStyle.inset
        textView.string = note.text
    }

    private func makeContent(around scroll: NSScrollView) -> NSView {
        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = NoteStyle.paper.cgColor
        root.layer?.cornerRadius = NoteStyle.radius
        root.layer?.cornerCurve = .continuous
        root.layer?.masksToBounds = true
        root.layer?.borderWidth = 1
        root.layer?.borderColor = NoteStyle.rim.cgColor
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        let close = NSButton(image: Self.dot(), target: self, action: #selector(closePressed))
        close.isBordered = false
        close.setAccessibilityLabel("Close note")
        for view in [close, scroll] {
            view.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview(view)
        }
        NSLayoutConstraint.activate([
            close.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: Self.dotMargin),
            close.topAnchor.constraint(equalTo: root.topAnchor),
            close.heightAnchor.constraint(equalToConstant: NoteStyle.barHeight),
            close.widthAnchor.constraint(equalToConstant: NoteStyle.barHeight - Self.dotMargin),
            scroll.topAnchor.constraint(equalTo: root.topAnchor, constant: NoteStyle.barHeight),
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])
        return root
    }

    @objc
    private func closePressed() {
        close()
    }
}
