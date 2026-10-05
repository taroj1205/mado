import AppCore
import Foundation
import GlassUI
import SearchKit

extension LauncherResult {
    @MainActor
    struct Home {
        private static let suggestionLimit = 6

        private(set) var favourites: [LauncherResult] = []
        private(set) var suggestions: [LauncherResult] = []
        private(set) var commands: [LauncherResult] = []

        init(in sources: Sources, usage: Usage, at now: Date, typed: Bool) {
            guard !typed else { return }
            let favouriteIDs = sources.items.favourites
            favourites = favouriteIDs.compactMap { LauncherResult.result(for: $0, in: sources) }
            suggestions = Array(
                usage.ranked(at: now).lazy
                    .filter { !favouriteIDs.contains($0) }
                    .compactMap { LauncherResult.result(for: $0, in: sources) }
                    .prefix(Self.suggestionLimit))
            let shown = Set(favouriteIDs + suggestions.map(\.id))
            commands = sources.commands.filter { !shown.contains($0.id) }
                .map(LauncherResult.command)
        }

        func sections(_ item: (LauncherResult) -> ResultList.Item) -> [ResultList.Section] {
            [
                ResultList.Section(title: "Favourites", items: favourites.map(item)),
                ResultList.Section(title: "Suggestions", items: suggestions.map(item)),
            ]
        }
    }
}
