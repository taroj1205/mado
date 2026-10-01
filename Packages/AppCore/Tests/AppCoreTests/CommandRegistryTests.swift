import Foundation
import Testing

@testable import AppCore

@MainActor
@Suite struct CommandRegistryTests {
    final class CommandModule: Module {
        let descriptor = ModuleDescriptor(
            id: "clipboard", name: "Clipboard", enabledByDefault: true,
            commandIDs: ["clipboard.open"])
        var stops = 0

        func start(context: ModuleContext) throws {
            try context.register(
                CommandRegistryTests.makeCommand(
                    "clipboard.open", name: "Open Clipboard", keywords: [], hotkey: nil))
        }

        func stop() {
            stops += 1
        }
    }

    final class Flag {
        var value = false
    }

    static func makeCommand(
        _ id: String, name: String, keywords: [String], hotkey: Shortcut?
    ) -> Command {
        Command(
            id: id, name: name, icon: "star",
            actions: [CommandAction(id: "run", title: "Run") { await Task.yield() }],
            keywords: keywords, hotkey: hotkey)
    }

    func makeStore() -> SettingsStore {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        return SettingsStore(url: dir.appending(path: "settings.json"))
    }

    @Test func registeredCommandsAreLookedUpByID() throws {
        let registry = CommandRegistry()
        let hotkey = Shortcut(keyCode: 49, modifiers: [.command])
        try registry.register(Self.makeCommand("a", name: "Alpha", keywords: [], hotkey: hotkey))
        try registry.register(Self.makeCommand("b", name: "Beta", keywords: [], hotkey: nil))

        #expect(registry.command(id: "a")?.name == "Alpha")
        #expect(registry.command(id: "a")?.hotkey == hotkey)
        #expect(registry.command(id: "a")?.actions.map(\.id) == ["run"])
        #expect(registry.command(id: "missing") == nil)
        #expect(registry.all.map(\.id) == ["a", "b"])
    }

    @Test func duplicateIDsAreRejected() throws {
        let registry = CommandRegistry()
        try registry.register(Self.makeCommand("a", name: "Alpha", keywords: [], hotkey: nil))

        #expect(throws: CommandError.duplicateCommand("a")) {
            try registry.register(Self.makeCommand("a", name: "Other", keywords: [], hotkey: nil))
        }
        #expect(registry.all.count == 1)
    }

    @Test func unregisterRemovesAndIsIdempotent() throws {
        let registry = CommandRegistry()
        try registry.register(Self.makeCommand("a", name: "Alpha", keywords: [], hotkey: nil))

        registry.unregister("a")
        registry.unregister("a")
        #expect(registry.command(id: "a") == nil)
        try registry.register(Self.makeCommand("a", name: "Alpha", keywords: [], hotkey: nil))
    }

    @Test func actionsRunOnTheMainActor() async throws {
        let ran = Flag()
        let command = Command(
            id: "a", name: "Alpha", icon: "star",
            actions: [CommandAction(id: "run", title: "Run") { ran.value = true }])

        try await command.actions[0].perform()
        #expect(ran.value)
    }

    @Test func disablingAModuleRemovesItsCommands() throws {
        let manager = try ModuleManager(store: makeStore())
        try manager.register(CommandModule())
        try manager.startEnabledModules()
        #expect(manager.commands.command(id: "clipboard.open") != nil)

        try manager.setEnabled("clipboard", false)
        #expect(manager.commands.all.isEmpty)

        try manager.setEnabled("clipboard", true)
        #expect(manager.commands.command(id: "clipboard.open") != nil)
    }
}
