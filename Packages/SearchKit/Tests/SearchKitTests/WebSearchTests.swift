import Foundation
import Testing

@testable import SearchKit

@Suite struct WebSearchTests {
    @Test func googleGetsTheQueryAsTyped() {
        #expect(
            WebSearch.googleURL(for: "c++ & a=b #1 100%")?.absoluteString
                == "https://www.google.com/search?q=c%2B%2B%20%26%20a%3Db%20%231%20100%25")
        #expect(
            WebSearch.googleURL(for: "日本")?.absoluteString
                == "https://www.google.com/search?q=%E6%97%A5%E6%9C%AC")
    }
}
