import Testing

@testable import SearchKit

@MainActor
@Suite struct SearchRunnerTests {
    @Test func skipsQueriesReplacedBeforeTheyStart() async {
        var searched: [String] = []
        var delivered: [String] = []
        let runner = SearchRunner<String>(
            search: { query in
                searched.append(query)
                return query
            },
            deliver: { delivered.append($0) })

        for query in ["s", "sa", "saf", "safa"] {
            runner.run(query)
        }
        await runner.task?.value

        #expect(searched == ["safa"])
        #expect(delivered == ["safa"])
    }

    @Test func dropsResultsOfAQueryReplacedWhileSearching() async {
        var gate: CheckedContinuation<Void, Never>?
        var searched: [String] = []
        var delivered: [String] = []
        let runner = SearchRunner<String>(
            search: { query in
                searched.append(query)
                if query == "s" {
                    await withCheckedContinuation { gate = $0 }
                }
                return query
            },
            deliver: { delivered.append($0) })

        runner.run("s")
        let stale = runner.task
        while gate == nil {
            await Task.yield()
        }
        runner.run("sa")
        await runner.task?.value
        gate?.resume()
        await stale?.value

        #expect(searched == ["s", "sa"])
        #expect(delivered == ["sa"])
    }
}
