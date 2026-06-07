import AppKit
import Foundation

enum ArtworkLoader {
    static let placeholder: NSImage = {
        NSImage(
            systemSymbolName: "music.note",
            accessibilityDescription: "Album Art"
        ) ?? NSImage(size: NSSize(width: 128, height: 128))
    }()

    static func load(urlString: String) async -> NSImage? {
        guard let url = URL(string: urlString), !urlString.isEmpty else {
            return nil
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 8
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return nil
            }
            return NSImage(data: data)
        } catch {
            return nil
        }
    }

    static func dominantColor(from image: NSImage?) -> NSColor {
        ColorExtractor.dominantColor(from: image)
    }
}
