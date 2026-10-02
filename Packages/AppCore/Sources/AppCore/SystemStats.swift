public struct SystemStats: Equatable, Sendable {
    public enum Power: Equatable, Sendable {
        case charging
        case charged
        case notCharging
        case draining(minutesLeft: Int?)
    }

    public struct Battery: Equatable, Sendable {
        public let level: Double
        public let power: Power
    }

    public struct Headphones: Equatable, Sendable {
        public let name: String
        public let level: Double
    }

    public enum VPN: Equatable, Sendable {
        case connected
        case disconnected
    }

    public enum WiFi: Equatable, Sendable {
        case off
        case disconnected
        case connected(network: String?)
    }

    public let cpu: Double?
    public let memory: Double?
    public let battery: Battery?
    public let diskFree: Int64?
    public let download: Double?
    public let headphones: Headphones?
    public let vpn: VPN?
    public let wifi: WiFi?
}
