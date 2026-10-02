import Foundation
import IOKit.ps

public actor SystemSampler {
    private typealias Statistics = (
        host_t, host_flavor_t, host_info_t?, UnsafeMutablePointer<mach_msg_type_number_t>?
    ) -> kern_return_t

    private let host = mach_host_self()
    private var meter: LoadMeter

    public init() {
        meter = LoadMeter()
    }

    private static func received() -> UInt64? {
        var name = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var size = 0
        guard unsafe sysctl(&name, u_int(name.count), nil, &size, nil, 0) == 0 else { return nil }
        var list = [UInt8](repeating: 0, count: size)
        guard unsafe sysctl(&name, u_int(name.count), &list, &size, nil, 0) == 0 else { return nil }
        return list.withUnsafeBytes { bytes in
            var total: UInt64 = 0
            var offset = 0
            while offset + MemoryLayout<if_msghdr2>.size <= size {
                let message = unsafe bytes.loadUnaligned(
                    fromByteOffset: offset, as: if_msghdr2.self)
                guard message.ifm_msglen > 0 else { break }
                if Int32(message.ifm_type) == RTM_IFINFO2 {
                    total += message.ifm_data.ifi_ibytes
                }
                offset += Int(message.ifm_msglen)
            }
            return total
        }
    }

    private static func battery() -> SystemStats.Battery? {
        guard let info = unsafe IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let sources = unsafe IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        return sources.lazy.compactMap { source -> SystemStats.Battery? in
            let found = unsafe IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue()
            guard let power = found as? [String: Any],
                power[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                power[kIOPSIsPresentKey] as? Bool == true,
                let charge = power[kIOPSCurrentCapacityKey] as? Double,
                let full = power[kIOPSMaxCapacityKey] as? Double, full > 0
            else { return nil }
            return SystemStats.Battery(
                level: min(max(charge / full, 0), 1),
                isCharging: power[kIOPSIsChargingKey] as? Bool == true)
        }
        .first
    }

    private static func diskFree() -> Int64? {
        try? URL(fileURLWithPath: NSHomeDirectory())
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage
    }

    public func sample() -> SystemStats {
        if let counters = counters() {
            meter.record(counters, at: .now)
        }
        return SystemStats(
            cpu: meter.cpu, memory: memory(), battery: Self.battery(), diskFree: Self.diskFree(),
            download: meter.download, headphones: Self.headphones(), vpn: Self.vpn(),
            wifi: Self.wifi())
    }

    private func counters() -> LoadMeter.Counters? {
        var load = host_cpu_load_info()
        guard unsafe read(HOST_CPU_LOAD_INFO, into: &load, with: host_statistics),
            let received = Self.received()
        else { return nil }
        let (user, system, idle, nice) = load.cpu_ticks
        return LoadMeter.Counters(busy: user &+ system &+ nice, idle: idle, received: received)
    }

    private func memory() -> Double? {
        var pages = vm_statistics64()
        var pageSize: vm_size_t = 0
        guard unsafe read(HOST_VM_INFO64, into: &pages, with: host_statistics64),
            unsafe host_page_size(host, &pageSize) == KERN_SUCCESS
        else { return nil }
        let unused =
            Double(pages.free_count) - Double(pages.speculative_count)
            + Double(pages.external_page_count)
        return 1 - unused * Double(pageSize) / Double(ProcessInfo.processInfo.physicalMemory)
    }

    private func read<Info>(
        _ flavor: host_flavor_t, into info: inout Info, with statistics: Statistics
    ) -> Bool {
        var count = mach_msg_type_number_t(MemoryLayout<Info>.size / MemoryLayout<integer_t>.size)
        return withUnsafeMutablePointer(to: &info) { pointer in
            unsafe pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { words in
                unsafe statistics(host, flavor, words, &count)
            }
        } == KERN_SUCCESS
    }
}
