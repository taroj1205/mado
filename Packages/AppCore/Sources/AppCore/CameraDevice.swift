public struct CameraDevice: Equatable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    public static func choose(from devices: [Self], saved: String?, preferred: String?) -> Self? {
        for wanted in [saved, preferred] {
            if let match = devices.first(where: { $0.id == wanted }) {
                return match
            }
        }
        return devices.first
    }
}
