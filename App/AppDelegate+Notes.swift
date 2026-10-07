extension AppDelegate {
    func notesRunningChanged() {
        if notes.isRunning, NotesSettings.assignDefaultHotKey(in: editor, modules: modules) {
            reloadSettings()
        }
        editor.refreshHotKey(for: NoteBoard.commandID)
    }
}
