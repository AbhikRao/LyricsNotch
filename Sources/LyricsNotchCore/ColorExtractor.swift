import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum ColorExtractor {
    static let fallbackGlow = NSColor(calibratedWhite: 0.16, alpha: 1)

    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    static func dominantColor(from image: NSImage?) -> NSColor {
        guard let image,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return fallbackGlow
        }

        let inputImage = CIImage(cgImage: cgImage)
        let filter = CIFilter.areaAverage()
        filter.inputImage = inputImage
        filter.extent = inputImage.extent

        guard let outputImage = filter.outputImage else {
            return fallbackGlow
        }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        let color = NSColor(
            calibratedRed: CGFloat(bitmap[0]) / 255,
            green: CGFloat(bitmap[1]) / 255,
            blue: CGFloat(bitmap[2]) / 255,
            alpha: 1
        )

        return color.adjustedForReadableGlow()
    }
}

private extension NSColor {
    func adjustedForReadableGlow() -> NSColor {
        guard let rgb = usingColorSpace(.deviceRGB) else { return ColorExtractor.fallbackGlow }

        let brightness = (0.299 * rgb.redComponent)
            + (0.587 * rgb.greenComponent)
            + (0.114 * rgb.blueComponent)
        let boost: CGFloat = brightness < 0.45 ? 0.34 : 0.14

        return NSColor(
            calibratedRed: min(rgb.redComponent + boost, 1),
            green: min(rgb.greenComponent + boost, 1),
            blue: min(rgb.blueComponent + boost, 1),
            alpha: 1
        )
    }
}
