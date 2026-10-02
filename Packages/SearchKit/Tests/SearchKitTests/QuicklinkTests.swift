import Foundation
import Testing

@testable import SearchKit

@Suite struct QuicklinkTests {
    private let youtube = Quicklink(
        name: "YouTube", link: "https://youtube.com/results?search_query={query}")

    @Test func fillsTheQueryIntoAWebLinkPercentEncoded() {
        #expect(
            youtube.url(for: "cats")?.absoluteString
                == "https://youtube.com/results?search_query=cats")
        #expect(
            youtube.url(for: "cats & dogs+1/2?#")?.absoluteString
                == "https://youtube.com/results?search_query=cats%20%26%20dogs%2B1%2F2%3F%23")
        #expect(
            youtube.url(for: "猫")?.absoluteString
                == "https://youtube.com/results?search_query=%E7%8C%AB")
        #expect(youtube.url(for: "")?.absoluteString == "https://youtube.com/results?search_query=")
    }

    @Test func fillsEveryPlaceholderAndLeavesLinksWithoutOneAlone() {
        let both = Quicklink(name: "Both", link: "https://example.com/{query}?q={query}")
        #expect(both.url(for: "a b")?.absoluteString == "https://example.com/a%20b?q=a%20b")

        let plain = Quicklink(name: "Mail", link: "https://mail.example.com/inbox")
        #expect(plain.url(for: "ignored")?.absoluteString == "https://mail.example.com/inbox")
    }

    @Test func folderLinksTakeTheQueryAsTypedAndExpandTheHomeFolder() {
        let projects = Quicklink(name: "Projects", link: "~/Projects/{query}")
        let url = projects.url(for: "mado app")
        #expect(url?.isFileURL == true)
        #expect(url?.path == NSHomeDirectory() + "/Projects/mado app")

        let root = Quicklink(name: "Apps", link: "/Applications")
        #expect(root.url(for: "")?.path == "/Applications")
    }

    @Test func appDeepLinksKeepTheirSchemeAndBareHostsGetHTTPS() {
        let things = Quicklink(name: "Things", link: "things:///add?title={query}")
        #expect(things.url(for: "buy milk")?.absoluteString == "things:///add?title=buy%20milk")

        let bare = Quicklink(name: "Example", link: " example.com/search?q={query} ")
        #expect(bare.url(for: "x")?.absoluteString == "https://example.com/search?q=x")

        #expect(Quicklink(name: "Empty", link: "").url(for: "x") == nil)
    }

    @Test func showsTheTypedQueryInPlaceOfTheSlot() {
        #expect(
            youtube.text(for: "cute cats") == "https://youtube.com/results?search_query=cute cats")
        #expect(youtube.text(for: "") == youtube.link)
    }

    @Test func takesTheQueryAfterAnAliasThatOpensTheLink() {
        #expect(youtube.query(in: "yt cats", aliases: ["yt"]) == "cats")
        #expect(youtube.query(in: "  YT   cute cats ", aliases: ["yt"]) == "cute cats")
        #expect(youtube.query(in: "ｙｔ cats", aliases: ["yt"]) == "cats")
        #expect(youtube.query(in: "yt", aliases: ["yt"]) == nil)
        #expect(youtube.query(in: "youtube cats", aliases: ["yt"]) == nil)
        #expect(youtube.query(in: "yt cats", aliases: []) == nil)
        #expect(youtube.query(in: "my tube cats", aliases: ["yt", " My Tube "]) == "cats")
        #expect(youtube.query(in: "ytcats", aliases: ["yt"]) == nil)

        let plain = Quicklink(name: "Mail", link: "https://mail.example.com")
        #expect(plain.query(in: "m inbox", aliases: ["m"]) == nil)
    }

    @Test func updatesALinkInPlaceOrAddsItAtTheEnd() throws {
        var links = Quicklinks()
        let mail = Quicklink(name: "Mail", link: "https://mail.example.com")
        links.update(youtube)
        links.update(mail)
        var renamed = youtube
        renamed.name = "YT"
        links.update(renamed)

        #expect(links.links.map(\.name) == ["YT", "Mail"])
        #expect(links[mail.id] == mail)
        #expect(links["missing"] == nil)
        #expect(youtube.id.hasPrefix("quicklink.") && youtube.id != mail.id)
        let decoded = try JSONDecoder().decode(
            Quicklinks.self, from: JSONEncoder().encode(links))
        #expect(decoded == links)
    }
}
