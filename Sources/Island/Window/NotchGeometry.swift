import AppKit

struct NotchGeometry {
    let notchSize: CGSize
    let hasNotch: Bool

    init(screen: NSScreen) {
        let top = screen.safeAreaInsets.top
        if top > 0 {
            hasNotch = true
            let left = screen.auxiliaryTopLeftArea?.width ?? 0
            let right = screen.auxiliaryTopRightArea?.width ?? 0
            let width = left > 0 && right > 0 ? screen.frame.width - left - right : 185
            notchSize = CGSize(width: width, height: top)
        } else {
            hasNotch = false
            let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
            notchSize = CGSize(width: 190, height: max(menuBar > 0 && menuBar < 50 ? menuBar : 24, 24))
        }
    }

    /// Kleine buitenwaartse rondingen bovenaan, zodat het eiland naadloos uit de schermrand loopt.
    var topRadius: CGFloat { 6 }
    var expandedSize: CGSize { CGSize(width: 560, height: notchSize.height + 148) }
    var windowSize: CGSize { CGSize(width: expandedSize.width + topRadius * 2 + 60, height: expandedSize.height + 40) }
}
