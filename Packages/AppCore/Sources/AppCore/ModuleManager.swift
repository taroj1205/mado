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

    private let store: SettingsStore
    private var settings: Settings
    private var states: States
    private var registered: [Registered] = []

    public var activeResources: [ActiveResource] {
        registered.flatMap(\.context.active)
    }

    public init(store: SettingsStore) throws {
        self.store = store
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
            Registered(module: module, context: ModuleContext(moduleID: id), isRunning: false))
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
        if enabled {
            try start(at: index)
        } else {
            stop(at: index)
        }
        states.enabled[id] = enabled
        try settings.setValue(states, for: Self.settingsKey)
        try store.save(settings)
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
