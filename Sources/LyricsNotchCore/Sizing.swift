import AppKit
import Foundation

public enum NotchMetrics {
    public static let openSize = CGSize(width: 640, height: 190)
    public static let compactOpenSize = CGSize(width: 430, height: 156)
    public static let minOpenSize = CGSize(width: 540, height: 176)
    public static let maxOpenSize = CGSize(width: 880, height: 330)
    public static let openCornerRadii = (top: CGFloat(19), bottom: CGFloat(24))
    public static let closedCornerRadii = (top: CGFloat(6), bottom: CGFloat(14))
    public static let fallbackClosedHeight = CGFloat(32)
    public static let fallbackClosedWidth = CGFloat(185)
    private static let openWidthKey = "openNotchWidth"
    private static let openHeightKey = "openNotchHeight"

    public static func closedSize(for screen: NSScreen? = NSScreen.main) -> CGSize {
        var width = fallbackClosedWidth
        var height = fallbackClosedHeight

        if let screen {
            if let leftArea = screen.auxiliaryTopLeftArea,
               let rightArea = screen.auxiliaryTopRightArea {
                width = screen.frame.width - leftArea.width - rightArea.width + 4
            }

            if screen.safeAreaInsets.top > 0 {
                height = screen.safeAreaInsets.top
            } else {
                height = screen.frame.maxY - screen.visibleFrame.maxY
                if height <= 0 {
                    height = fallbackClosedHeight
                }
            }
        }

        return CGSize(width: width, height: height)
    }

    public static func persistedOpenSize() -> CGSize {
        let width = UserDefaults.standard.double(forKey: openWidthKey)
        let height = UserDefaults.standard.double(forKey: openHeightKey)

        guard width > 0, height > 0 else {
            return openSize
        }

        return clampedOpenSize(CGSize(width: width, height: height))
    }

    public static func saveOpenSize(_ size: CGSize) {
        let clamped = clampedOpenSize(size)
        UserDefaults.standard.set(Double(clamped.width), forKey: openWidthKey)
        UserDefaults.standard.set(Double(clamped.height), forKey: openHeightKey)
    }

    public static func clampedOpenSize(_ size: CGSize) -> CGSize {
        CGSize(
            width: min(max(size.width, minOpenSize.width), maxOpenSize.width),
            height: min(max(size.height, minOpenSize.height), maxOpenSize.height)
        )
    }
}
