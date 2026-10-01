public import Foundation

public enum WebSearch {
    public static func googleURL(for query: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.google.com"
        components.path = "/search"
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacing("+", with: "%2B")
        return components.url
    }
}
