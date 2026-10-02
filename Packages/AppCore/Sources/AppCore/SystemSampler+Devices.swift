import CoreWLAN
import Foundation
import SystemConfiguration

extension SystemSampler {
    private static let buds = ["device_batteryLevelLeft", "device_batteryLevelRight"]
    private static let headsets: Set = ["Headphones", "Headset"]
    private static let percent = 100.0

    @concurrent
    static func headphones() async -> SystemStats.Headphones? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["-json", "-timeout", "2", "SPBluetoothDataType"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return headphones(inBluetoothProfile: data)
    }

    static func headphones(inBluetoothProfile data: Data) -> SystemStats.Headphones? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let bluetooth = (root["SPBluetoothDataType"] as? [[String: Any]])?.first,
            let devices = bluetooth["device_connected"] as? [[String: [String: Any]]]
        else { return nil }
        for (name, info) in devices.flatMap(\.self)
        where headsets.contains(info["device_minorType"] as? String ?? "") {
            let budLevel = buds.compactMap { level(info[$0]) }.min()
            if let found = budLevel ?? level(info["device_batteryLevelMain"]) {
                return SystemStats.Headphones(name: name, level: found)
            }
        }
        return nil
    }

    static func vpn() -> SystemStats.VPN? {
        guard let preferences = SCPreferencesCreate(nil, "Mado" as CFString, nil),
            let services = SCNetworkServiceCopyAll(preferences) as? [SCNetworkService]
        else { return nil }
        let statuses = services.compactMap(status(of:))
        guard !statuses.isEmpty else { return nil }
        return statuses.contains(.connected) ? .connected : .disconnected
    }

    static func wifi() -> SystemStats.WiFi? {
        guard let interface = CWWiFiClient.shared().interface() else { return nil }
        guard interface.powerOn() else { return .off }
        guard interface.interfaceMode() != .none else { return .disconnected }
        return .connected(network: interface.ssid())
    }

    private static func level(_ value: Any?) -> Double? {
        guard let text = value as? String else { return nil }
        return Double(text.prefix(while: \.isNumber)).map { min($0 / percent, 1) }
    }

    private static func status(of service: SCNetworkService) -> SCNetworkConnectionStatus? {
        guard !runsOnHardware(service), let id = SCNetworkServiceGetServiceID(service),
            let connection = SCNetworkConnectionCreateWithServiceID(nil, id, nil, nil)
        else { return nil }
        let status = SCNetworkConnectionGetStatus(connection)
        return status == .invalid ? nil : status
    }

    private static func runsOnHardware(_ service: SCNetworkService) -> Bool {
        var interface = SCNetworkServiceGetInterface(service)
        while let current = interface {
            if SCNetworkInterfaceGetBSDName(current) != nil { return true }
            interface = SCNetworkInterfaceGetInterface(current)
        }
        return false
    }
}
