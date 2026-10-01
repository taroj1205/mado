@MainActor
public final class ModuleManager {
    private struct Registered {
        let module: any Module
        let context: ModuleContext
        var isRunning: Bool
    }

    private struct States: Codable {
        var enabled: [String: Bool] = [:]
    }

    private static let settingsKey = "core"

    public let commands: CommandRegistry

    private let store: SettingsStore
    private var settings: Settings
    private var states: States
    private var registered: [Registered] = []

    public var activeResources: [ActiveResource] {
        registered.flatMap(\.context.active)
    }

    public init(store: SettingsStore, commands: CommandRegistry = CommandRegistry()) throws {
        self.store = store
        self.commands = commands
        let loaded = try store.load()
        settings = loaded
        states = try loaded.value(States.self, for: Self.settingsKey) ?? States()
    }

    public func register(_ module: any Module) throws {
        let id = module.descriptor.id
        guard !registered.contains(where: { $0.module.descriptor.id == id }) else {
            throw ModuleError.duplicateModule(id)
        }
        registered.append(
            Registered(
                module: module, context: ModuleContext(moduleID: id, commands: commands),
                isRunning: false))
    }

    public func isEnabled(_ id: String) -> Bool {
        states.enabled[id]
            ?? registered.first { $0.module.descriptor.id == id }?.module.descriptor
            .enabledByDefault ?? false
    }

    public func startEnabledModules() throws {
        for index in registered.indices where isEnabled(registered[index].module.descriptor.id) {
            try start(at: index)
        }
    }

    public func setEnabled(_ id: String, _ enabled: Bool) throws {
        guard let index = registered.firstIndex(where: { $0.module.descriptor.id == id }) else {
            throw ModuleError.unknownModule(id)
        }
        var nextStates = states
        nextStates.enabled[id] = enabled
        var nextSettings = settings
        try nextSettings.setValue(nextStates, for: Self.settingsKey)
        if enabled {
            let wasRunning = registered[index].isRunning
            try start(at: index)
            do {
                try store.save(nextSettings)
            } catch {
                if !wasRunning {
                    stop(at: index)
                }
                throw error
            }
        } else {
            try store.save(nextSettings)
            stop(at: index)
        }
        states = nextStates
        settings = nextSettings
    }

    public func value<Value: Decodable>(_ type: Value.Type, for key: String) throws -> Value? {
        try settings.value(type, for: key)
    }

    public func setValue<Value: Encodable>(_ value: Value, for key: String) throws {
        precondition(key != Self.settingsKey, "\(key) holds the module states")
        var nextSettings = settings
        try nextSettings.setValue(value, for: key)
        try store.save(nextSettings)
        settings = nextSettings
    }

    public func drain() async {
        for item in registered {
            await item.context.drain()
        }
    }

    private func start(at index: Int) throws {
        guard !registered[index].isRunning else { return }
        let item = registered[index]
        do {
            try item.module.start(context: item.context)
            registered[index].isRunning = true
        } catch {
            item.module.stop()
            item.context.releaseAll()
            throw error
        }
    }

    private func stop(at index: Int) {
        guard registered[index].isRunning else { return }
        registered[index].module.stop()
        registered[index].context.releaseAll()
        registered[index].isRunning = false
    }
}
