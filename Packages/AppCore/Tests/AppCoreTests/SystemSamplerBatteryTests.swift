import IOKit.ps
import Testing

@testable import AppCore

@Suite struct SystemSamplerBatteryTests {
    private func battery(
        charge: Double = 80, charging: Bool = false, charged: Bool = false,
        source: String = kIOPSBatteryPowerValue, minutesLeft: Int? = nil
    ) -> SystemStats.Battery? {
        var power: [String: Any] = [
            kIOPSTypeKey: kIOPSInternalBatteryType, kIOPSIsPresentKey: true,
            kIOPSCurrentCapacityKey: charge, kIOPSMaxCapacityKey: 100.0,
            kIOPSIsChargingKey: charging, kIOPSPowerSourceStateKey: source,
        ]
        if charged {
            power[kIOPSIsChargedKey] = true
        }
        if let minutesLeft {
            power[kIOPSTimeToEmptyKey] = minutesLeft
        }
        return SystemSampler.battery(from: power)
    }

    @Test func chargingWinsOverThePowerSource() {
        #expect(battery(charging: true, source: kIOPSACPowerValue)?.power == .charging)
    }

    @Test func onThePowerAdapterItIsChargedOrHeld() {
        let full = battery(charge: 100, charged: true, source: kIOPSACPowerValue)
        #expect(full == .init(level: 1, power: .charged))
        #expect(battery(source: kIOPSACPowerValue)?.power == .notCharging)
    }

    @Test func onBatteryItCountsDownOnlyOnceMacOSHasAnEstimate() {
        #expect(battery(minutesLeft: 200) == .init(level: 0.8, power: .draining(minutesLeft: 200)))
        #expect(battery(minutesLeft: -1)?.power == .draining(minutesLeft: nil))
        #expect(battery()?.power == .draining(minutesLeft: nil))
    }

    @Test func otherPowerSourcesAreNotTheMacBattery() {
        let ups: [String: Any] = [
            kIOPSTypeKey: kIOPSUPSType, kIOPSIsPresentKey: true,
            kIOPSCurrentCapacityKey: 50.0, kIOPSMaxCapacityKey: 100.0,
        ]
        #expect(SystemSampler.battery(from: ups) == nil)
    }
}
