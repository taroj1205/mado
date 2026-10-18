import SpeechKit

struct DictationSettings: StoredValue, Equatable {
    private enum CodingKeys: String, CodingKey {
        case model = "model"
        case languages = "spoken_languages"
        case words = "custom_words"
        case keepsRecordings = "keeps_recordings"
    }

    static let key = "dictation"

    var model: String?
    var languages: SpeechLanguages
    var words: SpeechWords
    var keepsRecordings: Bool

    init() {
        model = nil
        languages = SpeechLanguages()
        words = SpeechWords()
        keepsRecordings = false
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        model = try values.decodeIfPresent(String.self, forKey: .model)
        languages = try values.decodeIfPresent(SpeechLanguages.self, forKey: .languages) ?? .init()
        words = try values.decodeIfPresent(SpeechWords.self, forKey: .words) ?? .init()
        keepsRecordings = try values.decodeIfPresent(Bool.self, forKey: .keepsRecordings) ?? false
    }
}
