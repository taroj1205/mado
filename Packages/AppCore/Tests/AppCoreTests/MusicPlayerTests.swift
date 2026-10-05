import CoreServices
import Foundation
import Testing

@testable import AppCore

@Suite struct MusicPlayerTests {
    private typealias Event = NSAppleEventDescriptor

    private final class FakeApps: @unchecked Sendable {
        private static let names = [
            "pPlS", "pPIS", "ID  ", "pnam", "pArt", "pRaw", "aUrl", "pAlb", "pDur", "pPos",
        ]

        var answers: [String: [String: NSAppleEventDescriptor]] = [:]
        var asked: [String] = []
        var timingOut: Set<String> = []
        var covers: [URL: Data] = [:]
        var lagReads = 0
        private var pending: (() -> Void)?

        func answer(_ event: Event, to app: String) throws -> Event {
            guard let properties = answers[app] else { throw MusicPlayer.Failure.notRunning }
            if event.eventID == MusicPlayer.code("setd") {
                let target =
                    event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?
                    .forKeyword(AEKeyword(keyAEKeyData))?.typeCodeValue ?? 0
                asked.append(target == MusicPlayer.code("pPos") ? "seek" : "?")
                answers[app]?["pPos"] = event.paramDescriptor(forKeyword: AEKeyword(keyAEData))
                return .null()
            }
            guard event.eventID == MusicPlayer.code("getd") else {
                let suite = event.eventClass == MusicPlayer.code("spfy") ? "spfy" : "hook"
                let id = ["PlPs", "Prev", "Next"].first { MusicPlayer.code($0) == event.eventID }
                asked.append("\(app) \(suite)\(id ?? "?")")
                let change = { [self] in react(to: id ?? "", in: app) }
                if lagReads > 0 { pending = change } else { change() }
                return .null()
            }
            if let change = pending {
                lagReads -= 1
                if lagReads <= 0 {
                    change()
                    pending = nil
                }
            }
            let property =
                event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?
                .forKeyword(AEKeyword(keyAEKeyData))?.typeCodeValue ?? 0
            let name = Self.names.first { MusicPlayer.code($0) == property } ?? ""
            asked.append(name)
            if timingOut.contains(name) {
                throw NSError(domain: NSOSStatusErrorDomain, code: errAETimeout)
            }
            guard let found = properties[name] else {
                throw NSError(domain: NSOSStatusErrorDomain, code: errAENoSuchObject)
            }
            return found
        }

        private func react(to control: String, in app: String) {
            guard var properties = answers[app] else { return }
            if control == "PlPs" {
                let playing = properties["pPlS"]?.enumCodeValue == MusicPlayer.code("kPSP")
                properties["pPlS"] = NSAppleEventDescriptor(
                    enumCode: MusicPlayer.code(playing ? "kPSp" : "kPSP"))
            } else {
                let key = properties["pPIS"] == nil ? "ID  " : "pPIS"
                let id = properties[key]?.stringValue ?? ""
                properties[key] = NSAppleEventDescriptor(string: "\(id) \(control)")
            }
            answers[app] = properties
        }

        func cover(_ url: URL) throws -> Data {
            asked.append(url.absoluteString)
            guard let found = covers[url] else { throw URLError(.timedOut) }
            return found
        }
    }

    private static let music = MusicPlayer.Source.music.bundleID
    private static let spotify = MusicPlayer.Source.spotify.bundleID
    private static let cover = "https://i.scdn.co/image/ab67616d"

    private let apps = FakeApps()
    private let player: MusicPlayer

    init() {
        player = MusicPlayer(
            send: { [apps] event, app in try apps.answer(event, to: app) },
            load: { [apps] url in try apps.cover(url) })
        apps.answers[Self.music] = [
            "pPlS": state("kPSP"),
            "pPIS": NSAppleEventDescriptor(string: "A1B2"),
            "pnam": NSAppleEventDescriptor(string: "Low Tide"),
            "pArt": NSAppleEventDescriptor(string: "Harbour Lights"),
            "pRaw": NSAppleEventDescriptor(
                descriptorType: MusicPlayer.code("JPEG"), data: Data([0xFF, 0xD8])) ?? .null(),
        ]
    }

    private func state(_ code: String) -> NSAppleEventDescriptor {
        NSAppleEventDescriptor(enumCode: MusicPlayer.code(code))
    }

    private func count(_ name: String) -> Int {
        apps.asked.filter { $0 == name }.count
    }

    private func playSpotify(_ code: String = "kPSP") {
        apps.answers[Self.spotify] = [
            "pPlS": state(code),
            "ID  ": NSAppleEventDescriptor(string: "spotify:track:6rq"),
            "pnam": NSAppleEventDescriptor(string: "Night Drive"),
            "pArt": NSAppleEventDescriptor(string: "Neon Coast"),
            "aUrl": NSAppleEventDescriptor(string: Self.cover),
        ]
    }

    @Test func aPlayingMusicTrackReadsItsTitleArtistAndArtwork() async {
        #expect(
            await player.track()
                == .init(
                    id: "A1B2", title: "Low Tide", artist: "Harbour Lights", isPlaying: true,
                    artwork: Data([0xFF, 0xD8])))
    }

    @Test func theAlbumDurationAndPositionComeFromThePlayingApp() async {
        apps.answers[Self.music]?["pAlb"] = NSAppleEventDescriptor(string: "Salt")
        apps.answers[Self.music]?["pDur"] = NSAppleEventDescriptor(double: 201.4)
        apps.answers[Self.music]?["pPos"] = NSAppleEventDescriptor(double: 42.5)
        #expect(await player.position() == nil)
        let track = await player.track()
        #expect(track?.album == "Salt")
        #expect(track?.duration == 201.4)
        #expect(await player.position() == 42.5)
        playSpotify()
        apps.answers[Self.music] = nil
        apps.answers[Self.spotify]?["pDur"] = NSAppleEventDescriptor(int32: 201_400)
        #expect(await player.track()?.duration == 201.4)
    }

    @Test func aMissingAlbumDurationOrPositionIsLeftOut() async {
        let track = await player.track()
        #expect(track?.album.isEmpty == true)
        #expect(track?.duration == nil)
        #expect(await player.position() == nil)
    }

    @Test func seekingSetsThePlayerPositionOfTheShownApp() async throws {
        await #expect(throws: MusicPlayer.Failure.noTrack) { try await player.seek(to: 10) }
        _ = await player.track()
        try await player.seek(to: 73.5)
        #expect(count("seek") == 1)
        #expect(await player.position() == 73.5)
    }

    @Test func aPausedTrackStaysButAStoppedPlayerOrAMissingTrackShowsNothing() async {
        apps.answers[Self.music]?["pPlS"] = state("kPSp")
        #expect(await player.track()?.isPlaying == false)
        apps.answers[Self.music]?["pPlS"] = state("kPSS")
        #expect(await player.track() == nil)
        apps.answers[Self.music]?["pPlS"] = state("kPSP")
        apps.answers[Self.music]?["pnam"] = nil
        #expect(await player.track() == nil)
        apps.answers = [:]
        #expect(await player.track() == nil)
        await #expect(throws: MusicPlayer.Failure.noTrack) {
            _ = try await player.perform(.playPause)
        }
    }

    @Test func artworkIsReadOncePerTrack() async {
        _ = await player.track()
        _ = await player.track()
        #expect(count("pRaw") == 1)
        apps.answers[Self.music]?["pPIS"] = NSAppleEventDescriptor(string: "C3D4")
        apps.answers[Self.music]?["pRaw"] = nil
        #expect(await player.track()?.artwork == nil)
        #expect(count("pRaw") == 2)
        _ = await player.track()
        #expect(count("pRaw") == 2)
    }

    @Test func missingValueArtworkShowsNone() async {
        apps.answers[Self.music]?["pRaw"] = NSAppleEventDescriptor(
            typeCode: MusicPlayer.code("msng"))
        #expect(await player.track()?.artwork == nil)
    }

    @Test func aTimedOutArtworkReadIsTriedAgain() async {
        apps.timingOut = ["pRaw"]
        #expect(await player.track()?.artwork == nil)
        apps.timingOut = []
        #expect(await player.track()?.artwork == Data([0xFF, 0xD8]))
        #expect(count("pRaw") == 2)
    }

    @Test func spotifyLoadsItsCoverFromTheArtworkLinkAndRetriesAFailedDownload() async throws {
        apps.answers[Self.music] = nil
        playSpotify()
        let track = await player.track()
        #expect(track?.id == "spotify:track:6rq")
        #expect(track?.title == "Night Drive" && track?.artist == "Neon Coast")
        #expect(track?.artwork == nil)
        apps.covers[try #require(URL(string: Self.cover))] = Data([0x89, 0x50])
        #expect(await player.track()?.artwork == Data([0x89, 0x50]))
        _ = await player.track()
        #expect(count(Self.cover) == 2)
        apps.answers[Self.spotify]?["aUrl"] = NSAppleEventDescriptor(string: "")
        apps.answers[Self.spotify]?["ID  "] = NSAppleEventDescriptor(string: "spotify:track:7xx")
        #expect(await player.track()?.artwork == nil)
        _ = await player.track()
        #expect(count("aUrl") == 3)
    }

    @Test func thePlayingAppWinsAndControlsGoToIt() async throws {
        apps.answers[Self.music]?["pPlS"] = state("kPSp")
        playSpotify()
        #expect(await player.track()?.title == "Night Drive")
        let paused = try await player.perform(.playPause)
        #expect(paused?.title == "Night Drive" && paused?.isPlaying == false)
        _ = try await player.perform(.next)
        apps.answers[Self.spotify] = nil
        #expect(await player.track()?.title == "Low Tide")
        _ = try await player.perform(.previous)
        #expect(
            apps.asked.filter { $0.hasPrefix("com.") } == [
                "\(Self.spotify) spfyPlPs", "\(Self.spotify) spfyNext", "\(Self.music) hookPrev",
            ])
    }

    @Test func aControlWaitsForThePlayerToCatchUpBeforeReadingBack() async throws {
        apps.answers[Self.music] = nil
        playSpotify()
        _ = await player.track()
        apps.lagReads = 12
        #expect(try await player.perform(.playPause)?.isPlaying == false)
        #expect(try await player.perform(.next)?.id == "spotify:track:6rq Next")
    }
}
