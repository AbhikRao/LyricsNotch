import AppKit
import Foundation

public enum NotchState {
    case closed
    case open
}

public enum RepeatMode: Equatable, Sendable {
    case off
    case all
}

public struct SpotifyPlaybackState: Equatable, Sendable {
    public var isRunning: Bool
    public var isPlaying: Bool
    public var trackID: String
    public var title: String
    public var artist: String
    public var album: String
    public var position: Double
    public var duration: Double
    public var isShuffled: Bool
    public var repeatMode: RepeatMode
    public var artworkURL: String
    public var lastUpdated: Date

    public init(
        isRunning: Bool,
        isPlaying: Bool,
        trackID: String,
        title: String,
        artist: String,
        album: String,
        position: Double,
        duration: Double,
        isShuffled: Bool,
        repeatMode: RepeatMode,
        artworkURL: String,
        lastUpdated: Date
    ) {
        self.isRunning = isRunning
        self.isPlaying = isPlaying
        self.trackID = trackID
        self.title = title
        self.artist = artist
        self.album = album
        self.position = position
        self.duration = duration
        self.isShuffled = isShuffled
        self.repeatMode = repeatMode
        self.artworkURL = artworkURL
        self.lastUpdated = lastUpdated
    }

    public static let idle = SpotifyPlaybackState(
        isRunning: false,
        isPlaying: false,
        trackID: "",
        title: "",
        artist: "",
        album: "",
        position: 0,
        duration: 0,
        isShuffled: false,
        repeatMode: .off,
        artworkURL: "",
        lastUpdated: Date()
    )

    public var hasTrack: Bool {
        isRunning && !title.isEmpty && !artist.isEmpty
    }

    public var trackKey: String {
        if !trackID.isEmpty {
            return trackID
        }

        return [
            TextNormalizer.normalized(title),
            TextNormalizer.normalized(artist),
            String(Int(duration.rounded()))
        ].joined(separator: "|")
    }
}

public struct LyricLine: Identifiable, Equatable, Sendable {
    public let id: Int
    public let time: TimeInterval
    public let text: String
}

public enum LyricsStatus: Equatable {
    case idle
    case loading
    case synced
    case instrumental
    case notFound
    case failed(String)
}

public struct LRCLIBRecord: Decodable, Equatable, Sendable {
    public let id: Int
    public let trackName: String
    public let artistName: String
    public let albumName: String?
    public let duration: Double
    public let instrumental: Bool
    public let plainLyrics: String?
    public let syncedLyrics: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case trackName
        case artistName
        case albumName
        case duration
        case instrumental
        case plainLyrics
        case syncedLyrics
    }

    public init(
        id: Int,
        trackName: String,
        artistName: String,
        albumName: String?,
        duration: Double,
        instrumental: Bool,
        plainLyrics: String?,
        syncedLyrics: String?
    ) {
        self.id = id
        self.trackName = trackName
        self.artistName = artistName
        self.albumName = albumName
        self.duration = duration
        self.instrumental = instrumental
        self.plainLyrics = plainLyrics
        self.syncedLyrics = syncedLyrics
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = container.decodeFlexibleInt(forKey: .id) ?? 0
        trackName =
            container.decodeFlexibleString(forKey: .trackName)
            ?? container.decodeFlexibleString(forKey: .name)
            ?? ""
        artistName = container.decodeFlexibleString(forKey: .artistName) ?? ""
        albumName = container.decodeFlexibleString(forKey: .albumName)
        duration = container.decodeFlexibleDouble(forKey: .duration) ?? 0
        instrumental = container.decodeFlexibleBool(forKey: .instrumental) ?? false
        plainLyrics = container.decodeFlexibleString(forKey: .plainLyrics)
        syncedLyrics = container.decodeFlexibleString(forKey: .syncedLyrics)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleString(forKey key: K) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return String(value)
        }
        return nil
    }

    func decodeFlexibleDouble(forKey key: K) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Double(value)
        }
        return nil
    }

    func decodeFlexibleInt(forKey key: K) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Int(value)
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(value)
        }
        return nil
    }

    func decodeFlexibleBool(forKey key: K) -> Bool? {
        if let value = try? decodeIfPresent(Bool.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value != 0
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            switch value.lowercased() {
            case "true", "1", "yes":
                return true
            case "false", "0", "no":
                return false
            default:
                return nil
            }
        }
        return nil
    }
}
