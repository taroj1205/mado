import CoreGraphics
import Foundation
import Testing

@testable import AppCore

@Suite struct NoteStoreTests {
    private func temporaryStore() -> NoteStore {
        NoteStore(
            directory: FileManager.default.temporaryDirectory
                .appending(path: "mado-notes-\(UUID().uuidString)", directoryHint: .isDirectory))
    }

    @Test func aMissingFolderHoldsNoNotes() throws {
        #expect(try temporaryStore().load().isEmpty)
    }

    @Test func savedNotesComeBackWithTheirTextPositionAndState() throws {
        let store = temporaryStore()
        let note = Note(
            frame: CGRect(x: 640, y: 90, width: 300, height: 300),
            text: "Launch checklist\nWrite release notes", isOpen: false,
            modified: Date(timeIntervalSince1970: 1_790_000_000))
        try store.save(note)
        #expect(try store.load() == [note])
    }

    @Test func savingANoteAgainReplacesItInsteadOfAddingACopy() throws {
        let store = temporaryStore()
        var note = Note(frame: CGRect(x: 0, y: 0, width: 300, height: 300), text: "Groceries")
        try store.save(note)
        note.text = "Groceries\n納豆 × 3"
        try store.save(note)
        #expect(try store.load().map(\.text) == ["Groceries\n納豆 × 3"])
    }

    @Test func notesLoadOldestEditFirstAndSkipFilesThatAreNotNotes() throws {
        let store = temporaryStore()
        let frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        let newer = Note(
            frame: frame, text: "newer", modified: Date(timeIntervalSince1970: 1_790_000_100))
        let older = Note(
            frame: frame, text: "older", modified: Date(timeIntervalSince1970: 1_790_000_000))
        try store.save(newer)
        try store.save(older)
        try Data("not json".utf8).write(to: store.directory.appending(path: "broken.json"))
        try Data("ignored".utf8).write(to: store.directory.appending(path: "readme.txt"))
        #expect(try store.load().map(\.text) == ["older", "newer"])
    }
}
