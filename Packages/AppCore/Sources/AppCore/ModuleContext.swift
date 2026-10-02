public import CoreGraphics
public import Foundation
public import os

@MainActor
public final class ModuleContext {
    private struct Entry {
        let resource: ActiveResource
        let release: () -> Void
        let task: Task<Void, Never>?
    }

    public let logger: Logger
    public let signposter: OSSignposter

    private let moduleID: String
    private let commands: CommandRegistry
    private let eventTap: EventTap
    private var entries: [UInt: Entry] = [:]
    private var nextID: UInt = 0

    var active: [ActiveResource] {
        entries.keys.sorted().compactMap { entries[$0]?.resource }
    }

    init(moduleID: String, commands: CommandRegistry, eventTap: EventTap) {
        self.moduleID = moduleID
        self.commands = commands
        self.eventTap = eventTap
        logger = Log.logger(moduleID)
        signposter = Log.signposter(moduleID)
    }

    public func own(_ kind: ResourceKind, _ name: String, release: @escaping () -> Void) {
        add(Entry(resource: resource(kind, name), release: release, task: nil))
    }

    public func register(_ command: Command) throws {
        try commands.register(command)
        own(.other, "command:\(command.id)") { [commands] in
            commands.unregister(command.id)
        }
    }

    public func scheduleTimer(
        _ name: String, interval: TimeInterval, repeats: Bool = true,
        handler: @escaping @MainActor () -> Void
    ) {
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats) { _ in
            MainActor.assumeIsolated { handler() }
        }
        own(.timer, name) { timer.invalidate() }
    }

    public func tapEvents(
        _ name: String, matching types: [CGEventType],
        swallow: @escaping @MainActor (CGEventType, CGEvent) -> Bool
    ) throws(ModuleError) {
        guard let id = eventTap.add(types: types, swallow: swallow) else {
            throw .eventTapRefused(name)
        }
        own(.eventTap, name) { [eventTap] in eventTap.remove(id) }
    }

    public func run(_ name: String, operation: @escaping @MainActor @Sendable () async -> Void) {
        let id = nextID
        let task = Task { @MainActor [weak self] in
            await operation()
            self?.entries[id] = nil
        }
        add(Entry(resource: resource(.task, name), release: { task.cancel() }, task: task))
    }

    func releaseAll() {
        let released = entries
        for (id, entry) in released {
            entry.release()
            if entry.task == nil {
                entries[id] = nil
            }
        }
    }

    func drain() async {
        while let task = entries.values.compactMap(\.task).first {
            await task.value
            entries = entries.filter { $0.value.task != task }
        }
    }

    private func resource(_ kind: ResourceKind, _ name: String) -> ActiveResource {
        ActiveResource(module: moduleID, kind: kind, name: name)
    }

    private func add(_ entry: Entry) {
        entries[nextID] = entry
        nextID += 1
    }
}
