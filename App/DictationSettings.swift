struct DictationSettings: StoredValue, Equatable {
    static let key = "dictation"

    var model: String?

    init() {
        model = nil
    }
}
