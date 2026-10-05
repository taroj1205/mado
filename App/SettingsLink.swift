import AppCore
import GlassUI
import SearchKit

@MainActor
struct SettingsLink {
    typealias Opening = @MainActor @Sendable (SettingsSearch.Place, String?) -> Void

    static let kind = "Mado Settings"
    private static let openTitle = "Open in Settings"

    let id: String
    let location: SettingsFinder.Location
    let open: CommandAction

    var name: String {
        location.key ?? location.place.tab ?? location.place.page
    }

    var item: ResultList.Item {
        let place = location.place
        let path =
            location.key == nil
            ? (place.tab == nil ? "" : place.page)
            : [place.title, location.section].compactMap(\.self).joined(separator: " › ")
        let symbol = SettingsPage.all.first { $0.title == place.page }?.symbol
        return ResultList.Item(
            id: id, title: name, subtitle: path, kind: Self.kind, symbol: symbol ?? "gearshape",
            action: Self.openTitle)
    }

    init?(id: String, opening: @escaping Opening) {
        guard let found = SettingsFinder.Location(id: id),
            SettingsPage.all.contains(where: { $0.title == found.place.page })
        else { return nil }
        self.id = id
        location = found
        let spot = found.place
        let entry = found.key == nil ? nil : id
        open = CommandAction(id: "open", title: Self.openTitle) { opening(spot, entry) }
    }
}
