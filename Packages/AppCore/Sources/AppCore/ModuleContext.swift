import AppKit
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

    private static let timerTolerance = 0.1

    public let logger: Logger
    public let signposter: OSSignposter

    private let moduleID: String
    private let commands: CommandRegistry
    private let eventTap: EventTap
    private let listenTap: EventTap
    private var entries: [UInt: Entry] = [:]
    private var nextID: UInt = 0
    private var generation = 0
    var keysPaused = false
    private(set) var hasKeyFeatures = false

    var active: [ActiveResource] {
        entries.keys.sorted().compactMap { entries[$0]?.resource }
    }

    init(
        moduleID: String, commands: CommandRegistry, eventTap: EventTap, listenTap: EventTap
    ) {
        self.moduleID = moduleID
        self.commands = commands
        self.eventTap = eventTap
        self.listenTap = listenTap
        logger = Log.logger(moduleID)
        signposter = Log.signposter(moduleID)
    }

    public func startKeyFeatures(_ start: () -> Void) {
        hasKeyFeatures = true
        if !keysPaused {
            start()
        }
    }

    public func own(_ kind: ResourceKind, _ name: String, release: @escaping () -> Void) {
        add(Entry(resource: resource(kind, name), release: release, task: nil))
    }

    public func untilStopped<Value>(
        _ handler: @escaping @MainActor (Value) -> Void
    ) -> @MainActor (Value) -> Void {
        let started = generation
        return { [weak self] value in
            guard self?.generation == started else { return }
            handler(value)
        }
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
        timer.tolerance = interval * Self.timerTolerance
        own(.timer, name) { timer.invalidate() }
    }

    public func observe<Value: Sendable>(
        _ name: Notification.Name, on center: NotificationCenter,
        reading read: @escaping @Sendable (Notification) -> Value,
        handler: @escaping @MainActor (Value) -> Void
    ) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { notification in
            let value = read(notification)
            MainActor.assumeIsolated { handler(value) }
        }
        own(.observer, name.rawValue) { center.removeObserver(token) }
    }

    public func tapEvents(
        _ name: String, matching types: [CGEventType],
        swallow: @escaping @MainActor (CGEventType, CGEvent) -> Bool
    ) throws(ModuleError) {
        try ownRoute(name, on: eventTap, eventTap.add(types: types, swallow: swallow))
    }

    public func observeEvents(
        _ name: String, matching types: [CGEventType],
        observe: @escaping @MainActor (CGEventType, CGEvent) -> Void
    ) throws(ModuleError) {
        try ownRoute(name, on: eventTap, eventTap.observe(types: types, observe: observe))
    }

    public func observeGestures(
        _ name: String, observe: @escaping @MainActor (CGEvent) -> Void
    ) throws(ModuleError) {
        guard let gesture = CGEventType(rawValue: UInt32(NSEvent.EventType.gesture.rawValue)) else {
            throw .eventTapRefused(name)
        }
        try ownRoute(
            name, on: listenTap, listenTap.observe(types: [gesture]) { _, event in observe(event) })
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
        generation += 1
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

    private func ownRoute(_ name: String, on tap: EventTap, _ id: UInt?) throws(ModuleError) {
        guard let id else {
            throw .eventTapRefused(name)
        }
        own(.eventTap, name) { tap.remove(id) }
    }

    private func resource(_ kind: ResourceKind, _ name: String) -> ActiveResource {
        ActiveResource(module: moduleID, kind: kind, name: name)
    }

    private func add(_ entry: Entry) {
        entries[nextID] = entry
        nextID += 1
    }
}
