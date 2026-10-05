import AppCore

struct NotesModule: Module {
    static let id = "notes"

    let descriptor: ModuleDescriptor
    let menuBarAgenda: MenuBarAgendaItem
    let joinReminder = MeetingJoinReminder()
    unowned let modules: ModuleManager

    func start(context: ModuleContext) {
        menuBarAgenda.start(context: context, modules: modules)
        joinReminder.start(context: context, modules: modules)
    }

    func stop() {
        menuBarAgenda.stop()
        joinReminder.stop()
    }
}
