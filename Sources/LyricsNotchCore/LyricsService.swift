import Foundation

public enum LyricsServiceError: Error, Equatable {
    case invalidURL
    case badResponse
    case instrumental
    case missingSyncedLyrics
}

public final class LyricsService {
    private var cache: [String: [LyricLine]] = [:]
    private let session: URLSession
    private let requestTimeout: TimeInterval = 25

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func clearCache() {
        cache.removeAll()
    }

    public func syncedLyrics(
        trackName: String,
        artistName: String,
        albumName: String,
        duration: Double
    ) async throws -> [LyricLine] {
        let key = cacheKey(trackName: trackName, artistName: artistName, duration: duration)
        if let cached = cache[key] {
            return cached
        }

        let directRecord = try? await fetchDirectRecord(
            trackName: trackName,
            artistName: artistName,
            albumName: albumName,
            duration: duration
        )

        let records: [LRCLIBRecord]
        if let directRecord {
            records = [directRecord]
        } else {
            records = (try? await fetchSearchRecords(
                trackName: trackName,
                artistName: artistName
            )) ?? []
        }
        guard let record = Self.bestRecord(
            from: records,
            trackName: trackName,
            artistName: artistName,
            duration: duration
        ) else {
            if Self.hasMatchingInstrumental(
                in: records,
                trackName: trackName,
                artistName: artistName,
                duration: duration
            ) {
                throw LyricsServiceError.instrumental
            }
            let fallbackRecords = directRecord == nil ? records : ((try? await fetchSearchRecords(
                trackName: trackName,
                artistName: artistName
            )) ?? records)

            if Self.hasMatchingInstrumental(
                in: fallbackRecords,
                trackName: trackName,
                artistName: artistName,
                duration: duration
            ) {
                throw LyricsServiceError.instrumental
            }

            guard let fallbackRecord = Self.bestRecord(
                from: fallbackRecords,
                trackName: trackName,
                artistName: artistName,
                duration: duration
            ),
                  let synced = fallbackRecord.syncedLyrics,
                  !synced.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw LyricsServiceError.missingSyncedLyrics
            }

            let lines = LRCParser.parse(synced)
            guard !lines.isEmpty else {
                throw LyricsServiceError.missingSyncedLyrics
            }

            cache[key] = lines
            return lines
        }

        guard let synced = record.syncedLyrics,
              !synced.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LyricsServiceError.missingSyncedLyrics
        }

        let lines = LRCParser.parse(synced)
        guard !lines.isEmpty else {
            throw LyricsServiceError.missingSyncedLyrics
        }

        cache[key] = lines
        return lines
    }

    private func fetchDirectRecord(
        trackName: String,
        artistName: String,
        albumName: String,
        duration: Double
    ) async throws -> LRCLIBRecord? {
        guard !albumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              duration > 0,
              var components = URLComponents(string: "https://lrclib.net/api/get") else {
            return nil
        }

        components.queryItems = [
            URLQueryItem(name: "track_name", value: trackName),
            URLQueryItem(name: "artist_name", value: artistName),
            URLQueryItem(name: "album_name", value: albumName),
            URLQueryItem(name: "duration", value: String(Int(duration.rounded())))
        ]

        let (data, response) = try await performRequest(with: components)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LyricsServiceError.badResponse
        }

        if httpResponse.statusCode == 404 {
            return nil
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw LyricsServiceError.badResponse
        }

        return try JSONDecoder().decode(LRCLIBRecord.self, from: data)
    }

    private func fetchSearchRecords(
        trackName: String,
        artistName: String
    ) async throws -> [LRCLIBRecord] {
        var records: [LRCLIBRecord] = []

        if let structured = try? await fetchStructuredSearchRecords(
            trackName: trackName,
            artistName: artistName
        ) {
            records.append(contentsOf: structured)
        }

        if records.isEmpty,
           let loose = try? await fetchLooseSearchRecords(
            trackName: trackName,
            artistName: artistName
           ) {
            records.append(contentsOf: loose)
        }

        if records.isEmpty {
            throw LyricsServiceError.missingSyncedLyrics
        }

        return records
    }

    private func fetchStructuredSearchRecords(
        trackName: String,
        artistName: String
    ) async throws -> [LRCLIBRecord] {
        guard var components = URLComponents(string: "https://lrclib.net/api/search") else {
            throw LyricsServiceError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "track_name", value: trackName),
            URLQueryItem(name: "artist_name", value: artistName)
        ]

        let (data, response) = try await performRequest(with: components)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw LyricsServiceError.badResponse
        }

        return try JSONDecoder().decode([LRCLIBRecord].self, from: data)
    }

    private func fetchLooseSearchRecords(
        trackName: String,
        artistName: String
    ) async throws -> [LRCLIBRecord] {
        guard var components = URLComponents(string: "https://lrclib.net/api/search") else {
            throw LyricsServiceError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "q", value: "\(trackName) \(artistName)")
        ]

        let (data, response) = try await performRequest(with: components)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw LyricsServiceError.badResponse
        }

        return try JSONDecoder().decode([LRCLIBRecord].self, from: data)
    }

    private func performRequest(with components: URLComponents) async throws -> (Data, URLResponse) {
        guard let url = components.url else {
            throw LyricsServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("LyricsNotch/0.1.1 (https://github.com/AbhikRao/LyricsNotch)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = requestTimeout

        var latestError: Error?
        for attempt in 0..<3 {
            do {
                return try await session.data(for: request)
            } catch {
                latestError = error
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: UInt64(350_000_000 * (attempt + 1)))
                }
            }
        }

        throw latestError ?? LyricsServiceError.badResponse
    }

    public static func bestRecord(
        from records: [LRCLIBRecord],
        trackName: String,
        artistName: String,
        duration: Double
    ) -> LRCLIBRecord? {
        records
            .filter { record in
                guard let synced = record.syncedLyrics else { return false }
                return !record.instrumental && !synced.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .min { lhs, rhs in
                score(lhs, trackName: trackName, artistName: artistName, duration: duration)
                    < score(rhs, trackName: trackName, artistName: artistName, duration: duration)
            }
    }

    public static func hasMatchingInstrumental(
        in records: [LRCLIBRecord],
        trackName: String,
        artistName: String,
        duration: Double
    ) -> Bool {
        records.contains { record in
            guard record.instrumental else { return false }

            let trackMatches = TextNormalizer.roughlyMatches(record.trackName, trackName)
            let artistMatches = TextNormalizer.roughlyMatches(record.artistName, artistName)
            let durationMatches = duration <= 0
                || record.duration <= 0
                || abs(record.duration - duration) <= 4

            return trackMatches && artistMatches && durationMatches
        }
    }

    private static func score(
        _ record: LRCLIBRecord,
        trackName: String,
        artistName: String,
        duration: Double
    ) -> Double {
        var score = 0.0

        if !TextNormalizer.roughlyMatches(record.trackName, trackName) {
            score += 25
        }

        if !TextNormalizer.roughlyMatches(record.artistName, artistName) {
            score += 12
        }

        if duration > 0, record.duration > 0 {
            let difference = abs(record.duration - duration)
            score += min(difference, 30) / 2
        }

        return score
    }

    private func cacheKey(trackName: String, artistName: String, duration: Double) -> String {
        [
            TextNormalizer.normalized(trackName),
            TextNormalizer.normalized(artistName),
            String(Int(duration.rounded()))
        ].joined(separator: "|")
    }
}
