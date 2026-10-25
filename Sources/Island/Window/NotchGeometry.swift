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

    /// Hangt af van de instelling 'Grootte uitgeklapt'.
    var expandedSize: CGSize {
        let base = ExpandedSize.current.size
        return CGSize(width: base.width, height: notchSize.height + base.height)
    }

    /// Het venster is altijd groot genoeg voor de grootste stand.
    var windowSize: CGSize {
        let largest = ExpandedSize.large.size
        return CGSize(width: largest.width + topRadius * 2 + 60, height: notchSize.height + largest.height + 40)
    }
}
