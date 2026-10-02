import Foundation
import Testing

@testable import SearchKit

@Suite struct DictionaryLookupTests {
    private static let thesaurus = """
        <html xmlns:d="http://www.apple.com/DTDs/DictionaryService-1.0.rng"><body>\
        <d:entry class="entry"><span class="sg"><span class="se1 x_xd0">\
        <span class="msThes x_xd1 t_core"><span role="text" class="synList">\
        <span class="synGroup"><span d:def="1" class="syn t_core">transitory<d:def></d:def>\
        <span class="gp tg_syn">, </span></span><span class="syn">transient\
        <span class="gp tg_syn">, </span></span><span class="syn">fleeting\
        <span class="gp tg_syn">, </span></span><span class="syn">passing\
        <span class="gp tg_syn">, </span></span><span class="syn">short-lived\
        <span class="gp tg_syn">, </span></span><span class="syn">momentary</span></span>\
        </span><span role="text" class="antList"><span class="gp ty_label tg_antList">ANTONYMS\
        </span><span class="antGroup"><span class="ant">long-lived<span class="gp tg_ant">, \
        </span></span><span class="ant">permanent</span></span></span></span>\
        <span class="msThes x_xd1"><span class="syn">fugitive</span>\
        <span class="ant">lasting</span></span></span></span></d:entry></body></html>
        """

    private static let daijirin = """
        <html xmlns:d="http://www.apple.com/DTDs/DictionaryService-1.0.rng"><body>\
        <d:entry class="entry" lang="ja"><span class="sg"><span class="se1 x_xd0">\
        <span class="msDict x_xd2 hasSn t_first"><span d:def="1" class="df">\
        視覚的・聴覚的にきれいで心をうつ。<d:def/></span><span class="xrg"> ↔<span class="xr">\
        <a href="x-dictionary:r:229654:com.apple.dictionary.ja.Daijirin" type="対義語">醜い</a>\
        </span>。</span></span><span class="msDict x_xd2"><span class="xr">\
        <a href="x-dictionary:r:1:com.apple.dictionary.ja.Daijirin" type="対義語">汚い</a>\
        </span></span></span></span></d:entry></body></html>
        """

    @Test(arguments: [
        ("define ephemeral", "ephemeral"),
        ("  Define  ice cream ", "ice cream"),
        ("define ephemeral?", "ephemeral"),
        ("ephemeral?", "ephemeral"),
        ("Ephemeral?", "Ephemeral"),
        ("刹那？", "刹那"),
        ("美しい?", "美しい"),
    ])
    func defineOrAQuestionMarkAsksForAWord(query: String, term: String) {
        #expect(DictionaryLookup.term(in: query) == term)
    }

    @Test(arguments: [
        "ephemeral", "define", "define ?", "defined", "two words?", "5?", "?", "", "12 * 3?",
    ])
    func otherQueriesAreNotLookups(query: String) {
        #expect(DictionaryLookup.term(in: query) == nil)
    }

    @Test(arguments: [
        "define ephemeral", "define today", "ephemeral?", "tomorrow?", "noon?", "美しい?",
    ])
    func lookupsAreNotTakenByTheCalculatorAnswers(query: String) {
        #expect(Calculator.answer(for: query) == nil)
    }

    @Test(arguments: [
        ("fleeting", "define ephemeral", "define fleeting"),
        ("fleeting", "ephemeral?", "fleeting?"),
        ("for a short time", "ephemeral?", "define for a short time"),
    ])
    func aSimilarWordKeepsTheLookupInTheQuery(word: String, query: String, replaced: String) {
        #expect(DictionaryLookup.query(for: word, replacing: query) == replaced)
        #expect(DictionaryLookup.term(in: replaced) == word)
    }

    @Test func definitionsReadAsSentences() {
        #expect(
            DictionaryLookup.sentence("lasting for a very short time")
                == "Lasting for a very short time.")
        #expect(DictionaryLookup.sentence("きわめて短い時間。瞬間。") == "きわめて短い時間。瞬間。")
        #expect(DictionaryLookup.sentence(" ").isEmpty)
    }

    @Test func englishPronunciationsGetSlashesAndJapaneseReadingsDoNot() {
        #expect(DictionaryLookup.pronunciation("əˈfem(ə)rəl") == "/əˈfem(ə)rəl/")
        #expect(DictionaryLookup.pronunciation("うつくし・い") == "うつくし・い")
        #expect(DictionaryLookup.pronunciation("").isEmpty)
    }

    @Test func theFirstThesaurusSenseGivesFiveSimilarWordsAndItsOpposites() {
        let relations = DictionaryLookup.relations(in: Self.thesaurus)
        #expect(
            relations.similar == ["transitory", "transient", "fleeting", "passing", "short-lived"])
        #expect(relations.opposite == ["long-lived", "permanent"])
    }

    @Test func daijirinAntonymLinksBecomeOpposites() {
        let relations = DictionaryLookup.relations(in: Self.daijirin)
        #expect(relations.similar.isEmpty)
        #expect(relations.opposite == ["醜い"])
    }

    @Test func brokenMarkupHasNoRelations() {
        #expect(DictionaryLookup.relations(in: "<html><span class=\"syn\">").similar.isEmpty)
        #expect(DictionaryLookup.relations(in: "").opposite.isEmpty)
    }

    @Test func aRecordMatchesByHeadwordOrReading() {
        let fields = [
            "DCSTextElementKeyHeadword": "美しい", "DCSTextElementKeyPronunciation": "うつくし・い",
        ]
        #expect(DictionaryServices.names("美しい", fields))
        #expect(DictionaryServices.names("うつくしい", fields))
        #expect(
            DictionaryServices.names("EPHEMERAL", ["DCSTextElementKeyHeadword": "ephemeral"])
        )
        #expect(!DictionaryServices.names("run", ["DCSTextElementKeyHeadword": "running"]))
    }

    @Test(.enabled(if: DictionaryLookup.entry(for: "ephemeral")?.similar.isEmpty == false))
    func theMacDictionaryAndThesaurusFillTheCard() throws {
        let entry = try #require(DictionaryLookup.entry(for: "ephemeral"))
        #expect(entry.headword == "ephemeral")
        #expect(entry.pronunciation.hasPrefix("/") && entry.pronunciation.hasSuffix("/"))
        #expect(entry.partOfSpeech == "adjective")
        #expect(entry.definition.first?.isUppercase == true)
        #expect(entry.similar.contains("fleeting"))
        #expect(entry.opposite.contains("permanent"))
        #expect(!entry.dictionary.isEmpty)
        #expect(entry.url.absoluteString.hasPrefix("x-dictionary:d:ephemeral:"))
    }

    @Test(.enabled(if: DictionaryLookup.entry(for: "美しい")?.pronunciation == "うつくし・い"))
    func japaneseWordsComeFromDaijirinWithItsOpposites() throws {
        let entry = try #require(DictionaryLookup.entry(for: "美しい"))
        #expect(entry.headword == "美しい")
        #expect(entry.partOfSpeech == "形")
        #expect(entry.similar.isEmpty)
        #expect(entry.opposite == ["醜い"])
        #expect(entry.url.absoluteString.hasSuffix(DictionaryLookup.japaneseID))
        #expect(entry.japaneseURL == nil)
    }

    @Test(.enabled(if: DictionaryLookup.plainEntry(for: "ephemeral") != nil))
    func withoutThePrivateCallsThePublicDefinitionStillAnswers() throws {
        let entry = try #require(DictionaryLookup.plainEntry(for: "ephemeral"))
        #expect(entry.definition.contains("short time"))
        #expect(entry.url.scheme == "dict")
    }
}
