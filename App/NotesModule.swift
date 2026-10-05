import AppCore

struct NotesModule: Module {
    static let id = "notes"

    let descriptor: ModuleDescriptor
    let menuBarAgenda: MenuBarAgendaItem
    unowned let modules: ModuleManager

    func start(context: ModuleContext) {
        menuBarAgenda.start(context: context, modules: modules)
    }

    func stop() {
        menuBarAgenda.stop()
    }
}
