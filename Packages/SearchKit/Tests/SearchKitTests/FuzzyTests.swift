import Testing

@testable import SearchKit

@Suite struct FuzzyTests {
    private let names = ["Maps", "Photoshop", "Safari", "メモ", "Wasp", "Disk Space"]

    private func rank(_ query: String) -> [String] {
        Fuzzy.rank(names, by: query) { [$0] }
    }

    @Test func findsSafariByRomajiKanaAndFullWidth() {
        #expect(rank("safa") == ["Safari"])
        #expect(rank("さふぁ") == ["Safari"])
        #expect(rank("サファ") == ["Safari"])
        #expect(rank("ＳＡＦＡ") == ["Safari"])
        #expect(rank("fas").isEmpty)
    }

    @Test func findsKanaNamesByRomaji() {
        #expect(rank("memo") == ["メモ"])
        #expect(rank("めも") == ["メモ"])
    }

    @Test func dropsSeparatorsAddedByRomanizingKana() {
        #expect(Fuzzy.rank(["ShinAichi"], by: "しんあいち") { [$0] } == ["ShinAichi"])
        #expect(Fuzzy.rank(["Mac's メモ"], by: "mac's") { [$0] } == ["Mac's メモ"])
    }

    @Test func wordAndNameStartsRankFirst() {
        #expect(rank("ps") == ["Photoshop", "Maps"])
        #expect(
            Fuzzy.rank(["Speed Test", "Terminal"], by: "te") { [$0] } == ["Terminal", "Speed Test"])
    }

    @Test func picksTheBestAlignmentNotTheLeftmost() {
        #expect(rank("sp") == ["Disk Space", "Wasp", "Photoshop"])
    }

    @Test func matchReportsTheLettersOfTheBestAlignment() {
        #expect(Fuzzy.match("sp", in: "Disk Space")?.offsets == [5, 6])
        #expect(Fuzzy.match("lnch", in: "Launch at login")?.offsets == [0, 3, 4, 5])
        #expect(Fuzzy.match("cel", in: "Celsius (°C)")?.offsets == [0, 1, 2])
        #expect(Fuzzy.match("fas", in: "Safari") == nil)
        #expect(Fuzzy.match("memo", in: "メモ")?.offsets.isEmpty == true)
    }

    @Test func matchScoresLikeRank() {
        let candidates = ["Disk Space", "Wasp", "Photoshop"]
        let scores = candidates.map { Fuzzy.match("sp", in: $0)?.score ?? 0 }

        #expect(rank("sp") == ["Disk Space", "Wasp", "Photoshop"])
        #expect(scores == scores.sorted(by: >))
    }

    @Test func matchesAnyKeyAndKeepsOrderOnTies() {
        let commands = [("Open Clipboard", ["paste"]), ("Window Left", ["tile"])]
        let ranked = { (query: String) in
            Fuzzy.rank(commands, by: query) { [$0.0] + $0.1 }.map(\.0)
        }

        #expect(ranked("CLIP") == ["Open Clipboard"])
        #expect(ranked("til") == ["Window Left"])
        #expect(ranked("zzz").isEmpty)
        #expect(ranked("  ") == ["Open Clipboard", "Window Left"])
        #expect(ranked("e") == ["Open Clipboard", "Window Left"])
    }
}
