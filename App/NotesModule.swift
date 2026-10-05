import AppCore

struct NotesModule: Module {
    static let id = "notes"

    let descriptor: ModuleDescriptor
    let menuBar: MenuBarItems
    let joinReminder = MeetingJoinReminder()
    unowned let modules: ModuleManager

    func start(context: ModuleContext) {
        menuBar.agenda.start(context: context, modules: modules)
        menuBar.timer.start(modules: modules)
        joinReminder.start(context: context, modules: modules)
    }

    func stop() {
        menuBar.agenda.stop()
        menuBar.timer.stop()
        joinReminder.stop()
    }
}
