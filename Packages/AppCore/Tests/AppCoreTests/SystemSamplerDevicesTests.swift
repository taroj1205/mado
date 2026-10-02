import Foundation
import Testing

@testable import AppCore

@Suite struct SystemSamplerDevicesTests {
    private static let stale = """
        "device_not_connected": [ { "Old AirPods": {
            "device_batteryLevelLeft": "100%", "device_batteryLevelRight": "100%" } } ]
        """

    private func headphones(_ connected: String) -> SystemStats.Headphones? {
        let json = """
            { "SPBluetoothDataType": [ {
                "controller_properties": { "controller_state": "attrib_on" },
                "device_connected": [ \(connected) ],
                \(Self.stale)
            } ] }
            """
        return SystemSampler.headphones(inBluetoothProfile: Data(json.utf8))
    }

    @Test func connectedEarbudsShowTheLowerBud() {
        let found = headphones(
            """
            { "MX Master 3": { "device_batteryLevelMain": "60%", "device_minorType": "Mouse" } },
            { "AirPods Pro": {
                "device_batteryLevelCase": "100%", "device_batteryLevelLeft": "80%",
                "device_batteryLevelRight": "90%" } }
            """)
        #expect(found == .init(name: "AirPods Pro", level: 0.8))
    }

    @Test func oneBudIsEnough() {
        let found = headphones(#"{ "AirPods": { "device_batteryLevelRight": "45%" } }"#)
        #expect(found == .init(name: "AirPods", level: 0.45))
    }

    @Test func earbudsThatAreNotConnectedAreIgnored() {
        #expect(headphones("") == nil)
        #expect(SystemSampler.headphones(inBluetoothProfile: Data("not json".utf8)) == nil)
    }
}
