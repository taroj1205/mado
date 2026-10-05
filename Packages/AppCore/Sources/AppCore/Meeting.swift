public import Foundation

public struct Meeting: Sendable, Equatable {
    public enum Service: String, Sendable {
        case meet = "Google Meet"
        case teams = "Microsoft Teams"
        case zoom = "Zoom"
    }

    private static let zoomPaths = ["/j/", "/my/", "/w/"]
    private static let teamsPaths = ["/l/meetup-join/", "/meet/"]

    public let service: Service
    public let url: URL

    public init?(in texts: [String]) {
        guard
            let links = try? NSDataDetector(
                types: NSTextCheckingResult.CheckingType.link.rawValue)
        else { return nil }
        for text in texts {
            let range = NSRange(text.startIndex..., in: text)
            for match in links.matches(in: text, range: range) {
                if let link = match.url, let found = Self.service(of: link) {
                    service = found
                    url = link
                    return
                }
            }
        }
        return nil
    }

    static func service(of url: URL) -> Service? {
        guard let host = url.host()?.lowercased() else { return nil }
        let path = url.path().lowercased()
        let isUnder = { (domain: String) in host == domain || host.hasSuffix("." + domain) }
        if isUnder("zoom.us") || isUnder("zoomgov.com"), zoomPaths.contains(where: path.hasPrefix) {
            return .zoom
        }
        if host == "meet.google.com", path.wholeMatch(of: /\/[a-z]{3}-[a-z]{4}-[a-z]{3}/) != nil {
            return .meet
        }
        if host == "teams.microsoft.com", teamsPaths.contains(where: path.hasPrefix) {
            return .teams
        }
        if host == "teams.live.com", path.hasPrefix("/meet/") {
            return .teams
        }
        return nil
    }
}
