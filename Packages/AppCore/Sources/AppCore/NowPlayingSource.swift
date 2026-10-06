public import Foundation

public protocol NowPlayingSource: Sendable {
    func track(among players: Set<MusicPlayer.Player>) async -> MusicPlayer.Track?
    func position() async -> TimeInterval?
    func seek(to seconds: TimeInterval) async throws
    func perform(_ control: MusicPlayer.Control) async throws -> MusicPlayer.Track?
}

extension MusicPlayer: NowPlayingSource {}
