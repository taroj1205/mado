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
                /usr/bin/hidutil property --matching "$1" --set "$2"
                shift 2
            done
            """

        private let process = Process()
        private let input = Pipe()

        init(restoring arguments: [String]) throws {
            process.executableURL = URL(filePath: "/bin/sh")
            process.arguments = ["-c", Self.script, "sh"] + arguments
            process.standardInput = input
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            try? input.fileHandleForReading.close()
        }

        func cancel() {
            process.terminate()
            try? input.fileHandleForWriting.close()
        }
    }

    private static let matchingKeys = [
        kIOHIDVendorIDKey, kIOHIDProductIDKey, kIOHIDLocationIDKey, kIOHIDTransportKey,
        kIOHIDProductKey, kIOHIDPrimaryUsagePageKey, kIOHIDPrimaryUsageKey,
    ]

    private let logger = Log.logger("keyboard")
    private let client = IOHIDEventSystemClientCreateSimpleClient(kCFAllocatorDefault)
    private let settings: RemapSettings
    private let usage: UInt64
    private var mappings = KeyMappings()
    private var watcher: KeyboardWatcher?
    private var watchdog: Watchdog?

    public init?(settings: RemapSettings) {
        guard let destination = settings.capsLock.usage else { return nil }
        self.settings = settings
        usage = destination
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

    public func start() {
        watcher = KeyboardWatcher { [weak self] in self?.sync() }
        sync()
    }

    public func stop() {
        watcher = nil
        watchdog?.cancel()
        watchdog = nil
        write(mappings.restore(), to: Self.services(client))
    }

    private func sync() {
        let services = Self.services(client)
        var current: [UInt64: KeyMappings.Mapping] = [:]
        for service in services {
            let mapping = IOHIDServiceClientCopyProperty(
                service.client, KeyMappings.key as CFString)
            current[service.id] = mapping as? KeyMappings.Mapping ?? []
        }
        let remapping = Set(services.filter { settings.applies(to: $0.keyboard) }.map(\.id))
        let remapped = Set(mappings.originals.keys)
        let writes = mappings.sync(current, remapping: remapping, to: usage)
        guard Set(mappings.originals.keys) == remapped || arm(services) else {
            write(mappings.restore(), to: services)
            return
        }
        write(writes, to: services)
    }

    private func arm(_ services: [Service]) -> Bool {
        let previous = watchdog
        watchdog = nil
        defer { previous?.cancel() }
        var arguments: [String] = []
        for service in services {
            guard let original = mappings.originals[service.id] else { continue }
            guard
                let restore = KeyMappings.restoreArguments(
                    matching: service.matching, original: original)
            else {
                logger.error(
                    "Caps Lock remap can't be undone on \(service.keyboard.name, privacy: .public)")
                return false
            }
            arguments += [restore.matching, restore.mapping]
        }
        do {
            watchdog = try arguments.isEmpty ? nil : Watchdog(restoring: arguments)
            return true
        } catch {
            logger.error("Caps Lock remap watchdog failed: \(error, privacy: .public)")
            return false
        }
    }

    private func write(_ writes: [UInt64: KeyMappings.Mapping], to services: [Service]) {
        for service in services {
            guard let mapping = writes[service.id] else { continue }
            let saved = IOHIDServiceClientSetProperty(
                service.client, KeyMappings.key as CFString, mapping as CFArray)
            if !saved {
                logger.error("Caps Lock remap failed on \(service.keyboard.name, privacy: .public)")
            }
        }
    }
}
