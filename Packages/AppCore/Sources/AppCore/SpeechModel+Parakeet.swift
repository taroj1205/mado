extension SpeechModel {
    private static let europeanLanguages = 25
    private static let multilingualSize: Int64 = 483_257_242
    private static let multilingualMemory: Int64 = 142_000_000
    private static let japaneseSize: Int64 = 619_066_613
    private static let japaneseMemory: Int64 = 115_000_000

    static let parakeet: [Self] = [
        Self(
            id: "parakeet-tdt-v3", name: "Parakeet TDT v3", file: "parakeet-tdt-0.6b-v3",
            size: multilingualSize, memory: multilingualMemory, accuracy: .medium,
            languages: europeanLanguages, isJapaneseOnly: false,
            summary: "Very fast and light. English and 24 other European languages, not Japanese."),
        Self(
            id: "parakeet-tdt-ja", name: "Parakeet TDT Japanese", file: "parakeet-ja",
            size: japaneseSize, memory: japaneseMemory, accuracy: .medium, languages: 1,
            isJapaneseOnly: true,
            summary: "Very fast and light, for Japanese only. English speech comes out as Japanese."
        ),
    ]

    private init(
        id: String, name: String, file: String, size: Int64, memory: Int64, accuracy: Level,
        languages: Int, isJapaneseOnly: Bool, summary: String
    ) {
        self.id = id
        self.name = name
        self.file = file
        self.size = size
        self.memory = memory
        self.accuracy = accuracy
        self.languages = languages
        self.isJapaneseOnly = isJapaneseOnly
        self.summary = summary
        sha256 = nil
        engine = .parakeet
        isEnglishOnly = false
        isCompressed = false
        isFiveBit = false
        isMeasured = true
        isRecommended = false
        speed = .highest
    }
}
