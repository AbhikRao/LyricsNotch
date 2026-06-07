import AppKit

let outputPath = CommandLine.arguments.dropFirst().first ?? "dmg-background.png"
let size = CGSize(width: 720, height: 420)
let image = NSImage(size: size)

image.lockFocus()

let rect = NSRect(origin: .zero, size: size)
NSColor(calibratedRed: 0.035, green: 0.037, blue: 0.042, alpha: 1).setFill()
rect.fill()

let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.14, green: 0.16, blue: 0.20, alpha: 0.92),
    NSColor(calibratedRed: 0.03, green: 0.035, blue: 0.045, alpha: 1)
])
gradient?.draw(in: rect, angle: -90)

let glowPath = NSBezierPath(ovalIn: NSRect(x: 250, y: 240, width: 220, height: 80))
NSColor(calibratedRed: 0.52, green: 0.58, blue: 0.68, alpha: 0.20).setFill()
glowPath.fill()

let title = "Drag to Applications"
let subtitle = "then double click to open"

let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 34, weight: .bold),
    .foregroundColor: NSColor.white,
    .kern: 0.2
]
let subtitleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 19, weight: .medium),
    .foregroundColor: NSColor(calibratedWhite: 0.78, alpha: 1),
    .kern: 0.1
]

func drawCentered(_ text: String, y: CGFloat, attributes: [NSAttributedString.Key: Any]) {
    let attributed = NSAttributedString(string: text, attributes: attributes)
    let textSize = attributed.size()
    attributed.draw(at: NSPoint(x: (size.width - textSize.width) / 2, y: y))
}

drawCentered(title, y: 70, attributes: titleAttributes)
drawCentered(subtitle, y: 42, attributes: subtitleAttributes)

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fputs("Failed to render DMG background\n", stderr)
    exit(1)
}

try png.write(to: URL(fileURLWithPath: outputPath))
