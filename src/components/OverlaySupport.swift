import AppKit

enum OverlayMetrics {
    static let panelCornerRadius: CGFloat = 28
    static let inputCornerRadius: CGFloat = 16
    static let baseFrame = NSRect(x: 0, y: 0, width: 460, height: 136)
}

func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
    min(max(value, minValue), maxValue)
}
