public import Foundation

public struct ExchangeRates: Sendable, Equatable {
    private final class Reader: NSObject, XMLParserDelegate {
        var rates: [String: Double] = [:]

        func parser(
            _: XMLParser, didStartElement _: String, namespaceURI _: String?,
            qualifiedName _: String?, attributes: [String: String]
        ) {
            guard let code = attributes["currency"],
                let rate = attributes["rate"].flatMap(Double.init), rate.isFinite, rate > 0
            else { return }
            rates[code] = rate
        }
    }

    let perEuro: [String: Double]
    let fetched: Date

    init?(ecb data: Data, fetched: Date) {
        let reader = Reader()
        let parser = XMLParser(data: data)
        unsafe parser.delegate = reader
        guard parser.parse(), !reader.rates.isEmpty else { return nil }
        perEuro = reader.rates.merging(["EUR": 1]) { rate, _ in rate }
        self.fetched = fetched
    }

    init?(contentsOf url: URL) {
        guard let data = try? Data(contentsOf: url),
            let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate
        else { return nil }
        self.init(ecb: data, fetched: modified)
    }

    func has(_ code: String) -> Bool {
        perEuro[code] != nil
    }

    func convert(_ amount: Double, from source: String, to target: String) -> Double? {
        guard let sourceRate = perEuro[source], let targetRate = perEuro[target] else { return nil }
        return amount / sourceRate * targetRate
    }
}
