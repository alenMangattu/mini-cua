import AppKit

final class OverlayPanel: NSPanel {
    init(rootView: NSView, frame: NSRect = OverlayMetrics.baseFrame) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        isFloatingPanel = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        animationBehavior = .utilityWindow
        contentView = rootView
        applyRoundedMask()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(frameRect, display: flag)
        applyRoundedMask()
    }

    override func makeKeyAndOrderFront(_ sender: Any?) {
        super.makeKeyAndOrderFront(sender)
        applyRoundedMask()
    }

    private func applyRoundedMask() {
        contentView?.wantsLayer = true
        contentView?.layer?.cornerRadius = OverlayMetrics.panelCornerRadius
        contentView?.layer?.cornerCurve = .continuous
        contentView?.layer?.masksToBounds = true
        contentView?.layer?.backgroundColor = NSColor.clear.cgColor

        if let frameView = contentView?.superview {
            frameView.wantsLayer = true
            frameView.layer?.backgroundColor = NSColor.clear.cgColor

            let roundedPath = CGPath(
                roundedRect: frameView.bounds,
                cornerWidth: OverlayMetrics.panelCornerRadius,
                cornerHeight: OverlayMetrics.panelCornerRadius,
                transform: nil
            )

            let maskLayer = CAShapeLayer()
            maskLayer.path = roundedPath
            frameView.layer?.mask = maskLayer

            frameView.layer?.shadowPath = roundedPath
            frameView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.28).cgColor
            frameView.layer?.shadowOpacity = 1
            frameView.layer?.shadowRadius = 22
            frameView.layer?.shadowOffset = CGSize(width: 0, height: -8)
        }

        invalidateShadow()
    }
}
