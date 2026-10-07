import AppCore
import AppKit
import os

@MainActor
final class NoteBoard {
    static let commandID = "notes.new"
    private static let stagger: CGFloat = 24
    private static let half: CGFloat = 0.5
    private static let staggerSteps = 8

    var onRunningChange: (() -> Void)?
    private let logger = Log.logger("Notes")
    private var store: NoteStore?
    private var windows: [Note.ID: NoteWindow] = [:]
    private var unsaved: [Note.ID: Note] = [:]

    var isRunning: Bool {
        store != nil
    }

    func start(context: ModuleContext) {
        let opened: NoteStore
        do {
            opened = try .standard()
        } catch {
            context.logger.error("Notes failed to open: \(error, privacy: .public)")
            return
        }
        store = opened
        context.own(.other, "sticky notes") { [weak self] in self?.stop() }
        let new = CommandAction(id: "new", title: "New Note") { [weak self] in self?.newNote() }
        do {
            try context.register(
                Command(
                    id: Self.commandID, name: "New Note", icon: "note.text", actions: [new],
                    keywords: ["note", "sticky", "stickies", "memo"]))
        } catch {
            context.logger.error(
                "New note command failed: \(String(describing: error), privacy: .public)")
        }
        restore(from: opened, logger: context.logger)
        onRunningChange?()
    }

    func flush() {
        windows.values.forEach { $0.flush() }
        guard !unsaved.isEmpty, let kept = try? NoteStore.standard() else { return }
        for note in unsaved.values {
            do {
                try kept.save(note)
            } catch {
                logger.error("Saving a note failed: \(error, privacy: .public)")
            }
        }
    }

    private func stop() {
        for (id, pad) in windows where !pad.hide() {
            unsaved[id] = pad.note
        }
        windows = [:]
        store = nil
        onRunningChange?()
    }

    private func newNote() {
        let note = Note(frame: nextFrame())
        show(note, isStored: false, focusing: true)
    }

    private func restore(from opened: NoteStore, logger: Logger) {
        var notes: [Note] = []
        do {
            notes = try opened.load()
        } catch {
            logger.error("Notes failed to load: \(error, privacy: .public)")
        }
        let retained = unsaved
        unsaved = [:]
        notes.removeAll { retained[$0.id] != nil }
        notes += retained.values.sorted { $0.modified < $1.modified }
        for var note in notes where note.isOpen {
            note.frame = onScreen(note.frame)
            let pad = show(note, isStored: true, focusing: false)
            if retained[note.id] != nil { pad?.retrySave() }
        }
    }

    @discardableResult
    private func show(_ note: Note, isStored: Bool, focusing: Bool) -> NoteWindow? {
        guard let store else { return nil }
        let pad = NoteWindow(note: note, isStored: isStored, save: store.save) { [weak self] id in
            self?.forget(id)
        }
        windows[note.id] = pad
        pad.show(focusing: focusing)
        return pad
    }

    private func forget(_ id: Note.ID) {
        windows[id] = nil
    }

    private func onScreen(_ frame: CGRect) -> CGRect {
        let bar = CGRect(
            x: frame.minX, y: frame.maxY - NoteStyle.barHeight, width: frame.width,
            height: NoteStyle.barHeight)
        return NSScreen.screens.contains { $0.visibleFrame.intersects(bar) } ? frame : nextFrame()
    }

    private func nextFrame() -> CGRect {
        let area = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? .zero
        let step = CGFloat(windows.count % Self.staggerSteps) * Self.stagger
        let size = NoteStyle.size
        return CGRect(
            x: area.midX - size.width * Self.half + step,
            y: area.midY - size.height * Self.half - step, width: size.width, height: size.height)
    }
}
