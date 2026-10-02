public struct SystemStats: Equatable, Sendable {
    public struct Battery: Equatable, Sendable {
        public let level: Double
        public let isCharging: Bool
    }

    public let cpu: Double?
    public let memory: Double?
    public let battery: Battery?
    public let diskFree: Int64?
    public let download: Double?
}
