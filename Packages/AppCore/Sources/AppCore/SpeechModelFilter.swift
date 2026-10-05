import Foundation

public struct SpeechModelFilter: Equatable, Sendable {
    public enum Status: CaseIterable, Sendable {
        case any
        case downloaded
        case notDownloaded
    }

    public enum Language: CaseIterable, Sendable {
        case any
        case multilingual
        case englishOnly
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

    public var activeCount: Int {
        [status != .any, language != .any, size != .any, version != .any].filter(\.self).count
    }

    public init() {
        query = ""
        status = .any
        language = .any
        size = .any
        version = .any
    }

    public func matches(_ model: SpeechModel, isInstalled: Bool) -> Bool {
        matchesQuery(model) && matchesStatus(isInstalled) && matchesLanguage(model)
            && matchesSize(model) && matchesVersion(model)
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
        case .multilingual: !model.isEnglishOnly
        case .englishOnly: model.isEnglishOnly
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
