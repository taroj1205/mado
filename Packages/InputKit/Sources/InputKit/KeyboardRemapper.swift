import AppCore
import Foundation
import IOKit.hid
import IOKit.hidsystem
import os

@MainActor
public final class KeyboardRemapper {
    private struct Service {
        let id: UInt64
        let client: IOHIDServiceClient
        let keyboard: Keyboard
        let connection: Keyboard.Connection?
        let matching: [String: Any]
    }

    private struct Watchdog {
        private static let script = """
            read -r unused
            while [ "$#" -gt 1 ]; do
                /usr/bin/hidutil property --matching "$1" --set "$2" >/dev/null
                shift 2
            done
            """

        let arguments: [String]
        private let process = Process()
        private let input = Pipe()

        init(restoring arguments: [String], holding lock: FileHandle) throws {
            self.arguments = arguments
            process.executableURL = URL(filePath: "/bin/sh")
            process.arguments = ["-c", Self.script, "sh"] + arguments
            process.standardInput = input
            process.standardOutput = lock
            process.standardError = FileHandle.nullDevice
            try process.run()
            try? input.fileHandleForReading.close()
        }

        func cancel() {
            process.terminate()
            try? input.fileHandleForWriting.close()
        }

        func restoreNow() {
            try? input.fileHandleForWriting.close()
        }
    }

    private static let matchingKeys = [
        kIOHIDVendorIDKey, kIOHIDProductIDKey, kIOHIDLocationIDKey, kIOHIDTransportKey,
        kIOHIDProductKey, kIOHIDPrimaryUsagePageKey, kIOHIDPrimaryUsageKey,
    ]

    private static let lockURL = URL.temporaryDirectory.appending(path: "Mado-caps-lock.lock")
    private static let lockRetryMilliseconds = 100

    private let logger = Log.logger("keyboard")
    private let client = IOHIDEventSystemClientCreateSimpleClient(kCFAllocatorDefault)
    private let settings: RemapSettings
    private let usage: UInt64
    private let lock: RemapLock
    private var mappings = KeyMappings()
    private var waiting: Task<Void, Never>?
    private var watcher: KeyboardWatcher?
    private var watchdog: Watchdog?

    public init?(settings: RemapSettings) {
        guard let destination = settings.capsLock.usage else { return nil }
        guard let opened = RemapLock(url: Self.lockURL) else {
            logger.error("Caps Lock remap lock can't be opened")
            return nil
        }
        self.settings = settings
        usage = destination
        lock = opened
    }

    public static func connectedKeyboards() -> [(
        keyboard: Keyboard, connection: Keyboard.Connection?
    )] {
        var seen: Set<Keyboard> = []
        return services(IOHIDEventSystemClientCreateSimpleClient(kCFAllocatorDefault))
            .filter { seen.insert($0.keyboard).inserted }
            .map { ($0.keyboard, $0.connection) }
    }

    private static func services(_ client: IOHIDEventSystemClient) -> [Service] {
        let clients = IOHIDEventSystemClientCopyServices(client) as? [IOHIDServiceClient] ?? []
        return clients.compactMap(service)
    }

    private static func service(_ client: IOHIDServiceClient) -> Service? {
        let property = { (key: String) in IOHIDServiceClientCopyProperty(client, key as CFString) }
        guard property(kIOHIDPrimaryUsagePageKey) as? Int == kHIDPage_GenericDesktop,
            property(kIOHIDPrimaryUsageKey) as? Int == kHIDUsage_GD_Keyboard,
            let name = property(kIOHIDProductKey) as? String,
            let id = IOHIDServiceClientGetRegistryID(client) as? UInt64
        else {
            return nil
        }
        let keyboard = Keyboard(
            name: name, vendorID: property(kIOHIDVendorIDKey) as? Int ?? 0,
            productID: property(kIOHIDProductIDKey) as? Int ?? 0,
            layout: standardType(id).flatMap(Keyboard.Layout.init))
        let transport = property(kIOHIDTransportKey) as? String ?? ""
        let connection: Keyboard.Connection? =
            if property(kIOHIDBuiltInKey) as? Bool == true {
                .builtIn
            } else if transport.contains("Bluetooth") {
                .bluetooth
            } else if transport == "USB" {
                .usb
            } else {
                nil
            }
        let matching = matchingKeys.reduce(into: [String: Any]()) { $0[$1] = property($1) }
        return Service(
            id: id, client: client, keyboard: keyboard, connection: connection,
            matching: matching)
    }

    private static func standardType(_ id: UInt64) -> Int? {
        let entry = IOServiceGetMatchingService(kIOMainPortDefault, IORegistryEntryIDMatching(id))
        guard entry != 0 else { return nil }
        defer { IOObjectRelease(entry) }
        let value = unsafe IORegistryEntryCreateCFProperty(
            entry, kIOHIDStandardTypeKey as CFString, kCFAllocatorDefault, 0)
        return unsafe value?.takeRetainedValue() as? Int
    }

    private static func currentMappings(of services: [Service]) -> [UInt64: KeyMappings.Mapping] {
        services.reduce(into: [:]) { mappings, service in
            let mapping = IOHIDServiceClientCopyProperty(
                service.client, KeyMappings.key as CFString)
            mappings[service.id] = mapping as? KeyMappings.Mapping ?? []
        }
    }

    public func start() {
        waiting = Task { [weak self, lock] in
            while !Task.isCancelled {
                if lock.acquire() {
                    self?.begin()
                    return
                }
                try? await Task.sleep(for: .milliseconds(Self.lockRetryMilliseconds))
            }
        }
    }

    public func stop() {
        waiting?.cancel()
        waiting = nil
        guard watcher != nil else { return }
        watcher = nil
        let services = Self.services(client)
        let failed = write(mappings.restore(from: Self.currentMappings(of: services)), to: services)
        if failed.isEmpty {
            watchdog?.cancel()
            lock.release()
        } else {
            watchdog?.restoreNow()
        }
        watchdog = nil
    }

    private func begin() {
        watcher = KeyboardWatcher { [weak self] in self?.sync() }
        sync()
    }

    private func sync() {
        let services = Self.services(client)
        let current = Self.currentMappings(of: services)
        let remapping = Set(services.filter { settings.applies(to: $0.keyboard) }.map(\.id))
        let earlier = mappings
        let writes = mappings.sync(current, remapping: remapping, to: usage)
        guard armOrRestore(current, services) else { return }
        let failed = write(writes, to: services)
        guard !failed.isEmpty else { return }
        mappings.keepOriginals(of: failed, from: earlier)
        armOrRestore(current, services)
    }

    @discardableResult
    private func armOrRestore(
        _ current: [UInt64: KeyMappings.Mapping], _ services: [Service]
    ) -> Bool {
        guard arm(mappings.restores(from: current), services) else {
            write(mappings.restore(from: current), to: services)
            return false
        }
        return true
    }

    private func arm(_ restores: [UInt64: KeyMappings.Mapping], _ services: [Service]) -> Bool {
        var arguments: [String] = []
        for service in services {
            guard let mapping = restores[service.id] else { continue }
            guard
                let restore = KeyMappings.restoreArguments(
                    matching: service.matching, mapping: mapping)
            else {
                logger.error(
                    "Caps Lock remap can't be undone on \(service.keyboard.name, privacy: .public)")
                watchdog?.cancel()
                watchdog = nil
                return false
            }
            arguments += [restore.matching, restore.mapping]
        }
        guard arguments != watchdog?.arguments ?? [] else { return true }
        let previous = watchdog
        watchdog = nil
        defer { previous?.cancel() }
        do {
            watchdog =
                try arguments.isEmpty ? nil : Watchdog(restoring: arguments, holding: lock.handle)
            return true
        } catch {
            logger.error("Caps Lock remap watchdog failed: \(error, privacy: .public)")
            return false
        }
    }

    @discardableResult
    private func write(
        _ writes: [UInt64: KeyMappings.Mapping], to services: [Service]
    ) -> Set<UInt64> {
        var failed: Set<UInt64> = []
        for service in services {
            guard let mapping = writes[service.id] else { continue }
            let saved = IOHIDServiceClientSetProperty(
                service.client, KeyMappings.key as CFString, mapping as CFArray)
            if !saved {
                logger.error("Caps Lock remap failed on \(service.keyboard.name, privacy: .public)")
                failed.insert(service.id)
            }
        }
        return failed
    }
}
