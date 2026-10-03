public struct Keyboard: Codable, Hashable, Sendable {
    public enum Layout: Int, Codable, Sendable {
        case ansi = 0
        case iso = 1
        case jis = 2
    }

    public enum Connection: Sendable {
        case builtIn
        case bluetooth
        case usb
    }

    public let name: String
    public let vendorID: Int
    public let productID: Int
    public let layout: Layout?
}
