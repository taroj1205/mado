import Foundation

public struct SpeechModelFilter: Equatable, Sendable {
    public enum Order: CaseIterable, Sendable {
        case recommended
        case fastest
        case mostAccurate
        case bestOverall
        case smallest
    }

    public enum Rating: CaseIterable, Sendable {
        case any
        case high
        case highest

        var minimum: SpeechModel.Level? {
            switch self {
            case .any: nil
            case .high: .high
            case .highest: .highest
            }
        }

        func allows(_ level: SpeechModel.Level) -> Bool {
            level.rawValue >= minimum?.rawValue ?? 0
        }
    }

    public enum Status: CaseIterable, Sendable {
        case any
        case downloaded
        case notDownloaded
    }

    public enum Language: CaseIterable, Sendable {
        case any
        case multilingual
        case englishOnly
        case japaneseOnly
    }

    public enum Size: CaseIterable, Sendable {
        case any
        case under100MB
        case under500MB
        case under1GB

        private static let hundredMB: Int64 = 100_000_000
        private static let fiveHundredMB: Int64 = 500_000_000
        private static let oneGB: Int64 = 1_000_000_000

        public var limit: Int64? {
            switch self {
            case .any: nil
            case .under100MB: Self.hundredMB
            case .under500MB: Self.fiveHundredMB
            case .under1GB: Self.oneGB
            }
        }
    }

    public enum Version: CaseIterable, Sendable {
        case any
        case fullSize
        case compressed
    }

    public var query: String
    public var status: Status
    public var language: Language
    public var size: Size
    public var version: Version
    public var speed: Rating
    public var accuracy: Rating
    public var order: Order

    public var activeCount: Int {
        [
            status != .any, language != .any, size != .any, version != .any, speed != .any,
            accuracy != .any,
        ]
        .filter(\.self).count
    }

    private var sortKey: ((SpeechModel) -> [Int])? {
        switch order {
        case .recommended: nil
        case .fastest: { [$0.speed.rawValue, $0.accuracy.rawValue] }
        case .mostAccurate: { [$0.accuracy.rawValue, $0.speed.rawValue] }
        case .bestOverall: { [$0.speed.rawValue + $0.accuracy.rawValue, $0.accuracy.rawValue] }
        case .smallest: { [-Int($0.size)] }
        }
    }

    public init() {
        query = ""
        status = .any
        language = .any
        size = .any
        version = .any
        speed = .any
        accuracy = .any
        order = .recommended
    }

    public func shown(
        _ models: [SpeechModel], isInstalled: (SpeechModel) -> Bool
    ) -> [SpeechModel] {
        let matching = models.filter { model in matches(model, isInstalled: isInstalled(model)) }
        guard let key = sortKey else { return matching }
        return matching.enumerated()
            .sorted { lhs, rhs in
                let left = key(lhs.element)
                let right = key(rhs.element)
                return left == right
                    ? lhs.offset < rhs.offset : right.lexicographicallyPrecedes(left)
            }
            .map(\.element)
    }

    public func matches(_ model: SpeechModel, isInstalled: Bool) -> Bool {
        matchesQuery(model) && matchesStatus(isInstalled) && matchesLanguage(model)
            && matchesSize(model) && matchesVersion(model) && speed.allows(model.speed)
            && accuracy.allows(model.accuracy)
    }

    private func matchesQuery(_ model: SpeechModel) -> Bool {
        let words = query.split(separator: " ")
        return words.allSatisfy { model.name.localizedStandardContains($0) }
    }

    private func matchesStatus(_ isInstalled: Bool) -> Bool {
        switch status {
        case .any: true
        case .downloaded: isInstalled
        case .notDownloaded: !isInstalled
        }
    }

    private func matchesLanguage(_ model: SpeechModel) -> Bool {
        switch language {
        case .any: true
        case .multilingual: model.languages > 1
        case .englishOnly: model.isEnglishOnly
        case .japaneseOnly: model.isJapaneseOnly
        }
    }

    private func matchesSize(_ model: SpeechModel) -> Bool {
        guard let limit = size.limit else { return true }
        return model.size < limit
    }

    private func matchesVersion(_ model: SpeechModel) -> Bool {
        switch version {
        case .any: true
        case .fullSize: !model.isCompressed
        case .compressed: model.isCompressed
        }
    }
}
