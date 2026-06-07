import Foundation

public enum TextNormalizer {
    public static func normalized(_ value: String) -> String {
        let folded = value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        let withoutParentheticals = folded.replacingOccurrences(
            of: #"\s*[\(\[].*?[\)\]]\s*"#,
            with: " ",
            options: .regularExpression
        )

        let withoutPunctuation = withoutParentheticals.replacingOccurrences(
            of: #"[^a-z0-9]+"#,
            with: " ",
            options: .regularExpression
        )

        return withoutPunctuation
            .split(separator: " ")
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func roughlyMatches(_ left: String, _ right: String) -> Bool {
        let lhs = normalized(left)
        let rhs = normalized(right)

        if lhs.isEmpty || rhs.isEmpty {
            return false
        }

        return lhs == rhs || lhs.contains(rhs) || rhs.contains(lhs)
    }
}
