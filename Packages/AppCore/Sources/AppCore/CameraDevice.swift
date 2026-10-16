public struct CameraDevice: Equatable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    public static func ordered(from devices: [Self], saved: String?, preferred: String?) -> [Self] {
        var rest = devices
        var first: [Self] = []
        for wanted in [saved, preferred] {
            if let index = rest.firstIndex(where: { $0.id == wanted }) {
                first.append(rest.remove(at: index))
            }
        }
        return first + rest
    }
}
