import Foundation
import LyricsNotchCore

@main
struct LyricsNotchChecks {
    static func main() {
        checkLRCParsing()
        checkRecordRanking()
        checkInstrumentalDetection()
        checkTrackIDKey()
        print("LyricsNotch checks passed")
    }

    private static func checkLRCParsing() {
        let parsed = LRCParser.parse("""
        [ar:Artist]
        [00:01.50]First line
        [00:03.250]Second line
        [00:10.00][00:20.00]Repeat
        [00:30.00]
        """)

        expect(parsed.count == 4, "Expected four parsed lyric lines")
        expect(parsed[0].text == "First line", "Expected first lyric text")
        expect(abs(parsed[0].time - 1.5) < 0.001, "Expected centisecond timestamp")
        expect(abs(parsed[1].time - 3.25) < 0.001, "Expected millisecond timestamp")
        expect(parsed[2].text == "Repeat", "Expected repeated lyric text")
        expect(abs(parsed[3].time - 20) < 0.001, "Expected second repeated timestamp")
    }

    private static func checkRecordRanking() {
        let records = [
            record(id: 1, track: "Song", artist: "Artist", duration: 220, synced: nil),
            record(id: 2, track: "Song - Remastered", artist: "Artist", duration: 201, synced: "[00:01.00]A"),
            record(id: 3, track: "Song", artist: "Artist", duration: 200, synced: "[00:01.00]B"),
            record(id: 4, track: "Song", artist: "Artist", duration: 200, instrumental: true, synced: "[00:01.00]C")
        ]

        let best = LyricsService.bestRecord(
            from: records,
            trackName: "Song",
            artistName: "Artist",
            duration: 200
        )

        expect(best?.id == 3, "Expected synced non-instrumental exact duration match")
    }

    private static func checkInstrumentalDetection() {
        let records = [
            record(id: 1, track: "Ambient Loop", artist: "Composer", duration: 120, instrumental: true, synced: nil),
            record(id: 2, track: "Other", artist: "Composer", duration: 120, instrumental: true, synced: nil)
        ]

        let isInstrumental = LyricsService.hasMatchingInstrumental(
            in: records,
            trackName: "Ambient Loop",
            artistName: "Composer",
            duration: 120
        )

        expect(isInstrumental, "Expected matching instrumental detection")
    }

    private static func checkTrackIDKey() {
        let withID = SpotifyPlaybackState(
            isRunning: true,
            isPlaying: true,
            trackID: "spotify:track:abc",
            title: "Song",
            artist: "Artist",
            album: "Album",
            position: 0,
            duration: 180,
            isShuffled: false,
            repeatMode: .off,
            artworkURL: "",
            lastUpdated: Date()
        )

        let withoutID = SpotifyPlaybackState(
            isRunning: true,
            isPlaying: true,
            trackID: "",
            title: "Song (Remastered)",
            artist: "Artist",
            album: "Album",
            position: 0,
            duration: 180,
            isShuffled: false,
            repeatMode: .off,
            artworkURL: "",
            lastUpdated: Date()
        )

        expect(withID.trackKey == "spotify:track:abc", "Expected Spotify track ID as primary key")
        expect(withoutID.trackKey == "song|artist|180", "Expected normalized fallback key without track ID")
    }

    private static func record(
        id: Int,
        track: String,
        artist: String,
        duration: Double,
        instrumental: Bool = false,
        synced: String?
    ) -> LRCLIBRecord {
        LRCLIBRecord(
            id: id,
            trackName: track,
            artistName: artist,
            albumName: "Album",
            duration: duration,
            instrumental: instrumental,
            plainLyrics: nil,
            syncedLyrics: synced
        )
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("Check failed: \(message)\n", stderr)
            Foundation.exit(1)
        }
    }
}
