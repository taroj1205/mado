import AppCore
import Foundation

struct CameraSettings: StoredValue, Equatable {
    static let key = "camera"

    var mirrored: Bool
    var deviceID: String?
    var frame: CGRect?

    init() {
        mirrored = true
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        mirrored = try values.decodeIfPresent(Bool.self, forKey: .mirrored) ?? true
        deviceID = try values.decodeIfPresent(String.self, forKey: .deviceID)
        frame = try values.decodeIfPresent(CGRect.self, forKey: .frame)
    }
}
