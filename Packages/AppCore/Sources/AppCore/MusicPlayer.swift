import AppKit
import CoreServices
public import Foundation

public actor MusicPlayer {
    typealias Send = @Sendable (NSAppleEventDescriptor, String) throws -> NSAppleEventDescriptor
    typealias Load = @Sendable (URL) async throws -> Data

    public enum Player: String, CaseIterable, Sendable {
        case music = "apple_music"
        case spotify = "spotify"
    }

    public struct Track: Equatable, Sendable {
        public let id: String
        public let title: String
        public let artist: String
        public let isPlaying: Bool
        public var artwork: Data?
        public var album = ""
        public var duration: TimeInterval?
        public var player = MusicPlayer.Player.music
        public var bundleID = ""
    }

    public enum Control: Sendable {
        case playPause
        case previous
        case next

        var eventID: String {
            switch self {
            case .playPause: "PlPs"
            case .previous: "Prev"
            case .next: "Next"
            }
        }
    }

    public enum Failure: Error {
        case notRunning
        case noResult
        case noTrack
        case badResponse
    }

    enum Artwork: Equatable, Sendable {
        case rawData
        case link
    }

    struct Source: Equatable, Sendable {
        static let music = Source(
            bundleID: "com.apple.Music", trackID: "pPIS", artwork: .rawData, suite: "hook",
            player: .music)
        static let spotify = Source(
            bundleID: "com.spotify.client", trackID: "ID  ", artwork: .link, suite: "spfy",
            player: .spotify, durationUnit: MusicPlayer.millisecond)

        let bundleID: String
        let trackID: String
        let artwork: Artwork
        let suite: String
        let player: MusicPlayer.Player
        var durationUnit = 1.0
    }

    private static let sources = [Source.music, .spotify]
    private static let millisecond = 0.001
    private static let timeout: TimeInterval = 2
    private static let loadTimeout: TimeInterval = 5
    private static let httpOK = 200
    private static let settleTries = 10
    private static let settleStep = Duration.milliseconds(100)
    private static let stopped = code("kPSS")
    private static let paused = code("kPSp")

    private static let toApp: Send = { event, bundleID in
        guard
            let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .first(where: { !$0.isTerminated })
        else { throw Failure.notRunning }
        event.setAttribute(
            NSAppleEventDescriptor(processIdentifier: app.processIdentifier),
            forKeyword: AEKeyword(keyAddressAttr))
        let reply = try event.sendEvent(options: .waitForReply, timeout: timeout)
        return reply.paramDescriptor(forKeyword: AEKeyword(keyDirectObject)) ?? .null()
    }

    private static let fromWeb: Load = { url in
        let (data, response) = try await URLSession.shared.data(
            for: URLRequest(url: url, timeoutInterval: loadTimeout))
        guard (response as? HTTPURLResponse)?.statusCode == httpOK else {
            throw Failure.badResponse
        }
        return data
    }

    private static var currentTrack: NSAppleEventDescriptor { property("pTrk") }

    private static var firstArtwork: NSAppleEventDescriptor {
        specifier(
            want: code("cArt"), form: OSType(formAbsolutePosition),
            data: NSAppleEventDescriptor(int32: 1), of: currentTrack)
    }

    private let send: Send
    private let load: Load
    private var source: Source?
    private var allowed = Set(Player.allCases)
    private var artwork: (id: String, data: Data?)?

    public init() {
        self.init(send: Self.toApp, load: Self.fromWeb)
    }

    init(send: @escaping Send, load: @escaping Load) {
        self.send = send
        self.load = load
    }

    static func code(_ text: String) -> FourCharCode {
        text.utf8.reduce(0) { $0 << UInt8.bitWidth | FourCharCode($1) }
    }

    private static func property(
        _ name: String, of container: NSAppleEventDescriptor = .null()
    ) -> NSAppleEventDescriptor {
        specifier(
            want: OSType(cProperty), form: OSType(formPropertyID),
            data: NSAppleEventDescriptor(typeCode: code(name)), of: container)
    }

    private static func specifier(
        want: DescType, form: DescType, data: NSAppleEventDescriptor,
        of container: NSAppleEventDescriptor
    ) -> NSAppleEventDescriptor {
        let record = NSAppleEventDescriptor.record()
        record.setDescriptor(
            NSAppleEventDescriptor(typeCode: want), forKeyword: AEKeyword(keyAEDesiredClass))
        record.setDescriptor(
            NSAppleEventDescriptor(enumCode: form), forKeyword: AEKeyword(keyAEKeyForm))
        record.setDescriptor(data, forKeyword: AEKeyword(keyAEKeyData))
        record.setDescriptor(container, forKeyword: AEKeyword(keyAEContainer))
        return record.coerce(toDescriptorType: DescType(typeObjectSpecifier)) ?? record
    }

    private static func event(_ eventClass: String, _ id: String) -> NSAppleEventDescriptor {
        NSAppleEventDescriptor(
            eventClass: code(eventClass), eventID: code(id), targetDescriptor: nil,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID))
    }

    public func track(among players: Set<Player> = Set(Player.allCases)) async -> Track? {
        allowed = players
        let found = Self.sources.filter { players.contains($0.player) }
            .compactMap { app in read(app).map { (app, $0) } }
        let shown = found.first(where: \.1.isPlaying) ?? found.first { $0.0 == source }
        guard let (app, current) = shown ?? found.first else {
            source = nil
            return nil
        }
        source = app
        var playing = current
        if artwork?.id != playing.id, let art = await artwork(of: playing.id, in: app) {
            artwork = art
        }
        playing.artwork = artwork?.id == playing.id ? artwork?.data : nil
        return playing
    }

    public func perform(_ control: Control) async throws -> Track? {
        guard let source else { throw Failure.noTrack }
        let before = read(source)
        _ = try send(Self.event(source.suite, control.eventID), source.bundleID)
        for _ in 0..<Self.settleTries {
            guard read(source) == before else { break }
            try await Task.sleep(for: Self.settleStep)
        }
        return await track(among: allowed)
    }

    private func read(_ app: Source) -> Track? {
        guard let state = try? get(Self.property("pPlS"), from: app).enumCodeValue,
            state != Self.stopped,
            let id = try? string(app.trackID, from: app),
            let title = try? string("pnam", from: app),
            let artist = try? string("pArt", from: app)
        else { return nil }
        return Track(
            id: id, title: title, artist: artist, isPlaying: state != Self.paused,
            album: (try? string("pAlb", from: app)) ?? "",
            duration: (try? number("pDur", of: Self.currentTrack, from: app))
                .map { $0 * app.durationUnit },
            player: app.player, bundleID: app.bundleID)
    }

    public func position() -> TimeInterval? {
        guard let source else { return nil }
        return try? number("pPos", of: .null(), from: source)
    }

    public func seek(to seconds: TimeInterval) throws {
        guard let source else { throw Failure.noTrack }
        let event = Self.event("core", "setd")
        event.setParam(Self.property("pPos"), forKeyword: AEKeyword(keyDirectObject))
        event.setParam(NSAppleEventDescriptor(double: seconds), forKeyword: AEKeyword(keyAEData))
        _ = try send(event, source.bundleID)
    }

    private func number(
        _ name: String, of container: NSAppleEventDescriptor, from app: Source
    ) throws -> Double {
        let reply = try get(Self.property(name, of: container), from: app)
        guard reply.descriptorType != typeNull else { throw Failure.noResult }
        return reply.doubleValue
    }

    private func artwork(of id: String, in app: Source) async -> (id: String, data: Data?)? {
        switch app.artwork {
        case .rawData:
            do {
                let found = try get(Self.property("pRaw", of: Self.firstArtwork), from: app)
                return (id, found.descriptorType == typeType ? nil : found.data)
            } catch {
                let failure = error as NSError
                let missing =
                    failure.domain == NSOSStatusErrorDomain && failure.code == errAENoSuchObject
                return missing ? (id, nil) : nil
            }

        case .link:
            guard let link = try? string("aUrl", from: app) else { return nil }
            guard let url = URL(string: link), url.scheme == "https" else { return (id, nil) }
            return (try? await load(url)).map { (id, $0) }
        }
    }

    private func string(_ name: String, from app: Source) throws -> String {
        let reply = try get(Self.property(name, of: Self.currentTrack), from: app)
        guard let text = reply.stringValue else { throw Failure.noResult }
        return text
    }

    private func get(
        _ specifier: NSAppleEventDescriptor, from app: Source
    ) throws -> NSAppleEventDescriptor {
        let event = Self.event("core", "getd")
        event.setParam(specifier, forKeyword: AEKeyword(keyDirectObject))
        return try send(event, app.bundleID)
    }
}
