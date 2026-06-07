import Foundation

enum AppleScriptHelper {
    static func execute(_ source: String) throws -> NSAppleEventDescriptor {
        let script = NSAppleScript(source: source)
        var error: NSDictionary?

        if let descriptor = script?.executeAndReturnError(&error) {
            return descriptor
        }

        let userInfo = error as? [String: Any] ?? [
            NSLocalizedDescriptionKey: "AppleScript execution failed."
        ]
        throw NSError(domain: "LyricsNotch.AppleScript", code: 1, userInfo: userInfo)
    }

    static func executeVoid(_ source: String) throws {
        _ = try execute(source)
    }
}
