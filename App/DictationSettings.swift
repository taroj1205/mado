import SpeechKit

struct DictationSettings: StoredValue, Equatable {
    private enum CodingKeys: String, CodingKey {
        case model = "model"
        case languages = "spoken_languages"
    }

    static let key = "dictation"

    var model: String?
    var languages: SpeechLanguages

    init() {
        model = nil
        languages = SpeechLanguages()
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        model = try values.decodeIfPresent(String.self, forKey: .model)
        languages = try values.decodeIfPresent(SpeechLanguages.self, forKey: .languages) ?? .init()
    }
}
