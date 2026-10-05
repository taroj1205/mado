import Testing

@testable import AppCore

@Suite struct SpeechModelFilterTests {
    private func ids(_ filter: SpeechModelFilter, installed: Set<String> = []) -> [String] {
        SpeechModel.all.filter { filter.matches($0, isInstalled: installed.contains($0.id)) }
            .map(\.id)
    }

    @Test func noFilterShowsEveryModel() {
        #expect(ids(SpeechModelFilter()).count == SpeechModel.all.count)
        #expect(SpeechModelFilter().activeCount == 0)
    }

    @Test func everySearchWordHasToMatchTheName() {
        var filter = SpeechModelFilter()
        filter.query = "turbo q5"
        #expect(ids(filter) == ["large-v3-turbo-q5_0"])
        filter.query = "SMALL english"
        #expect(ids(filter) == ["small.en", "small.en-q8_0", "small.en-q5_1"])
    }

    @Test func filtersNarrowByStatusLanguageSizeAndVersion() {
        var filter = SpeechModelFilter()
        filter.status = .downloaded
        #expect(ids(filter, installed: ["base"]) == ["base"])
        filter.status = .notDownloaded
        #expect(!ids(filter, installed: ["base"]).contains("base"))
        filter = SpeechModelFilter()
        filter.language = .englishOnly
        filter.size = .under100MB
        filter.version = .fullSize
        #expect(ids(filter) == ["tiny.en"])
        #expect(filter.activeCount == 3)
        filter.language = .multilingual
        filter.version = .compressed
        #expect(ids(filter) == ["tiny-q8_0", "tiny-q5_1", "base-q8_0", "base-q5_1"])
    }

    @Test func speedAndAccuracyKeepModelsAtOrAboveTheLevel() {
        var filter = SpeechModelFilter()
        filter.speed = .highest
        let fastest = SpeechModel.all.filter { filter.matches($0, isInstalled: false) }
        #expect(fastest.count == 12 && fastest.allSatisfy { $0.speed == .highest })
        filter.accuracy = .high
        #expect(ids(filter).isEmpty)
        filter = SpeechModelFilter()
        filter.accuracy = .highest
        filter.language = .multilingual
        #expect(ids(filter) == ["large-v3-turbo", "large-v3", "large-v3-turbo-q8_0"])
        #expect(filter.activeCount == 2)
    }

    @Test func sortingPutsTheBestFirstAndKeepsCatalogOrderForTies() {
        var filter = SpeechModelFilter()
        let first = { (order: SpeechModelFilter.Order) -> [String] in
            filter.order = order
            return filter.shown(SpeechModel.all) { _ in false }.prefix(3).map(\.id)
        }
        #expect(
            first(.bestOverall) == ["large-v3-turbo", "large-v3-turbo-q8_0", "large-v3-turbo-q5_0"])
        #expect(first(.fastest) == ["base", "base-q8_0", "base.en"])
        #expect(first(.mostAccurate).first == "large-v3-turbo")
        #expect(first(.smallest).first == "tiny-q5_1")
        #expect(first(.recommended) == SpeechModel.all.prefix(3).map(\.id))
        #expect(filter.activeCount == 0)
    }
}
