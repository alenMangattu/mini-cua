import AppKit

final class LoadingDotsView: NSVisualEffectView {
    private let contrastTint = NSView()
    private var dotViews: [NSView] = []
    private let dotSize: CGFloat = 12
    private let dotTravel: CGFloat = 10

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        material = .sidebar
        blendingMode = .behindWindow
        state = .active
        isEmphasized = true
        appearance = NSAppearance(named: .vibrantDark)
        wantsLayer = true

        if let layer {
            layer.cornerRadius = OverlayMetrics.panelCornerRadius
            layer.cornerCurve = .continuous
            layer.masksToBounds = true
            layer.borderWidth = 1
            layer.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
            layer.backgroundColor = NSColor.black.withAlphaComponent(0.04).cgColor
        }

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        startAnimating()
    }

    private func setupLayout() {
        contrastTint.wantsLayer = true
        contrastTint.layer?.cornerRadius = OverlayMetrics.panelCornerRadius
        contrastTint.layer?.cornerCurve = .continuous
        contrastTint.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.10).cgColor
        contrastTint.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contrastTint)

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 14
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false

        for _ in 0..<3 {
            let dot = NSView()
            dot.wantsLayer = true
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.layer?.cornerRadius = dotSize / 2
            dot.layer?.cornerCurve = .continuous
            dot.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.92).cgColor
            dot.layer?.shadowColor = NSColor.white.withAlphaComponent(0.24).cgColor
            dot.layer?.shadowOpacity = 1
            dot.layer?.shadowRadius = 8
            dot.layer?.shadowOffset = .zero
            dotViews.append(dot)
            row.addArrangedSubview(dot)

            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: dotSize),
                dot.heightAnchor.constraint(equalToConstant: dotSize),
            ])
        }

        addSubview(row)

        NSLayoutConstraint.activate([
            contrastTint.leadingAnchor.constraint(equalTo: leadingAnchor),
            contrastTint.trailingAnchor.constraint(equalTo: trailingAnchor),
            contrastTint.topAnchor.constraint(equalTo: topAnchor),
            contrastTint.bottomAnchor.constraint(equalTo: bottomAnchor),

            row.centerXAnchor.constraint(equalTo: centerXAnchor),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    private func startAnimating() {
        for (index, dot) in dotViews.enumerated() {
            dot.layer?.removeAllAnimations()

            let bounce = CABasicAnimation(keyPath: "transform.translation.y")
            bounce.fromValue = 0
            bounce.toValue = dotTravel
            bounce.duration = 0.42
            bounce.autoreverses = true
            bounce.repeatCount = .infinity
            bounce.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            bounce.beginTime = CACurrentMediaTime() + (Double(index) * 0.12)
            dot.layer?.add(bounce, forKey: "bounce")

            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.45
            fade.toValue = 1.0
            fade.duration = 0.42
            fade.autoreverses = true
            fade.repeatCount = .infinity
            fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            fade.beginTime = bounce.beginTime
            dot.layer?.add(fade, forKey: "fade")
        }
    }
}

final class LoadingOverlayController {
    let panel: OverlayPanel
    private let contentView = LoadingDotsView(frame: NSRect(x: 0, y: 0, width: 240, height: 96))
    private var screenObserver: NSObjectProtocol?

    init() {
        panel = OverlayPanel(rootView: contentView, frame: NSRect(x: 0, y: 0, width: 240, height: 96))

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reposition()
        }
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    func show() {
        reposition()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func reposition() {
        guard let screen = targetScreen() else { return }
        let visible = screen.visibleFrame
        let width = clamp(visible.width * 0.16, min: 220, max: 280)
        let height = clamp(visible.height * 0.075, min: 88, max: 108)
        let bottomInset = clamp(visible.height * 0.08, min: 48, max: 96)

        panel.setFrame(
            NSRect(
                x: visible.midX - width / 2,
                y: visible.minY + bottomInset,
                width: width,
                height: height
            ),
            display: true
        )
    }

    private func targetScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }
}

final class LoadingAppDelegate: NSObject, NSApplicationDelegate {
    private var loadingController: LoadingOverlayController?
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = LoadingOverlayController()
        loadingController = controller
        controller.show()

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                NSApp.terminate(nil)
                return nil
            }
            return event
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }
}

@main
struct LoadingOverlayApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = LoadingAppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
