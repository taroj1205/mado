import AppCore
import GlassUI

struct ColourPickerSettings: StoredValue, Equatable {
    static let key = "colour_picker"

    var keys: LoupeKeys

    init() {
        keys = LoupeKeys()
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        keys = try values.decodeIfPresent(LoupeKeys.self, forKey: .keys) ?? keys
    }
}
