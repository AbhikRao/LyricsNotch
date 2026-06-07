import Foundation

public enum LRCParser {
    public static func parse(_ source: String) -> [LyricLine] {
        let pattern = #"\[(\d{1,2}):(\d{2})(?:[\.:](\d{1,3}))?\]"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let lines = source.components(separatedBy: .newlines)
        var parsed: [(time: TimeInterval, text: String)] = []

        for line in lines {
            let nsLine = line as NSString
            let range = NSRange(location: 0, length: nsLine.length)
            let matches = regex?.matches(in: line, range: range) ?? []

            guard !matches.isEmpty, let lastMatch = matches.last else { continue }

            let textStart = lastMatch.range.location + lastMatch.range.length
            let text = nsLine.substring(from: min(textStart, nsLine.length))
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else { continue }

            for match in matches {
                guard let time = timestamp(from: match, in: nsLine) else { continue }
                parsed.append((time, text))
            }
        }

        return parsed
            .sorted { lhs, rhs in
                if lhs.time == rhs.time {
                    return lhs.text < rhs.text
                }
                return lhs.time < rhs.time
            }
            .enumerated()
            .map { index, item in
                LyricLine(id: index, time: item.time, text: item.text)
            }
    }

    private static func timestamp(from match: NSTextCheckingResult, in line: NSString) -> TimeInterval? {
        guard match.numberOfRanges >= 3 else { return nil }

        let minuteRange = match.range(at: 1)
        let secondRange = match.range(at: 2)

        guard minuteRange.location != NSNotFound,
              secondRange.location != NSNotFound,
              let minutes = Double(line.substring(with: minuteRange)),
              let seconds = Double(line.substring(with: secondRange)) else {
            return nil
        }

        var fraction = 0.0
        if match.numberOfRanges > 3 {
            let fractionRange = match.range(at: 3)
            if fractionRange.location != NSNotFound {
                let raw = line.substring(with: fractionRange)
                if let value = Double(raw) {
                    if raw.count == 1 {
                        fraction = value / 10
                    } else if raw.count == 2 {
                        fraction = value / 100
                    } else {
                        fraction = value / 1000
                    }
                }
            }
        }

        return minutes * 60 + seconds + fraction
    }
}
