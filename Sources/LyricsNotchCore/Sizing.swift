import AppKit
import Foundation

public enum NotchMetrics {
    public static let openSize = CGSize(width: 640, height: 190)
    public static let openCornerRadii = (top: CGFloat(19), bottom: CGFloat(24))
    public static let closedCornerRadii = (top: CGFloat(6), bottom: CGFloat(14))
    public static let fallbackClosedHeight = CGFloat(32)
    public static let fallbackClosedWidth = CGFloat(185)

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
}
