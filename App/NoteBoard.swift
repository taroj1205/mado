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
    private var store: NoteStore?
    private var windows: [Note.ID: NoteWindow] = [:]

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
        context.observe(
            NSApplication.willTerminateNotification, on: .default, reading: { $0.name },
            handler: { [weak self] _ in self?.flush() })
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
        do {
            for var note in try opened.load() where note.isOpen {
                note.frame = onScreen(note.frame)
                show(note, isStored: true, focusing: false)
            }
        } catch {
            context.logger.error("Notes failed to load: \(error, privacy: .public)")
        }
        onRunningChange?()
    }

    func flush() {
        windows.values.forEach { $0.flush() }
    }

    private func stop() {
        windows.values.forEach { $0.hide() }
        windows = [:]
        store = nil
        onRunningChange?()
    }

    private func newNote() {
        let note = Note(frame: nextFrame())
        show(note, isStored: false, focusing: true)
    }

    private func show(_ note: Note, isStored: Bool, focusing: Bool) {
        guard let store else { return }
        let pad = NoteWindow(note: note, isStored: isStored, save: store.save) { [weak self] id in
            self?.forget(id)
        }
        windows[note.id] = pad
        pad.show(focusing: focusing)
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
