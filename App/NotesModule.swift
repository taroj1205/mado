import AppCore

struct NotesModule: Module {
    struct Screens {
        let menuBar: MenuBarItems
        let board: NoteBoard
    }

    static let id = "notes"

    let descriptor: ModuleDescriptor
    let screens: Screens
    let joinReminder = MeetingJoinReminder()
    unowned let modules: ModuleManager

    func start(context: ModuleContext) {
        screens.board.start(context: context)
        screens.menuBar.agenda.start(context: context, modules: modules)
        screens.menuBar.timer.start(modules: modules)
        joinReminder.start(context: context, modules: modules)
    }

    func stop() {
        screens.menuBar.agenda.stop()
        screens.menuBar.timer.stop()
        joinReminder.stop()
    }
}
