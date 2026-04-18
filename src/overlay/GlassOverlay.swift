import AppKit

private func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
    min(max(value, minValue), maxValue)
}

final class GlassPanel: NSPanel {
    init() {
        let frame = NSRect(x: 0, y: 0, width: 520, height: 160)
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .statusBar
        isFloatingPanel = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
        ]
        animationBehavior = .utilityWindow
        contentView = GlassRootView(frame: frame)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class GlassRootView: NSVisualEffectView {
    private let titleLabel = NSTextField(labelWithString: "Overlay")
    private let hintLabel = NSTextField(labelWithString: "Press Esc to close")
    private let inputShell = NSView()
    private let inputField = NSTextField()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .hudWindow
        blendingMode = .behindWindow
        state = .active
        isEmphasized = true
        wantsLayer = true

        if let layer {
            layer.cornerRadius = 28
            layer.masksToBounds = true
            layer.borderWidth = 1
            layer.borderColor = NSColor.white.withAlphaComponent(0.24).cgColor
            layer.backgroundColor = NSColor.white.withAlphaComponent(0.035).cgColor
        }

        setupLabels()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLabels() {
        titleLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        titleLabel.textColor = NSColor.white.withAlphaComponent(0.96)

        hintLabel.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        hintLabel.textColor = NSColor.white.withAlphaComponent(0.60)

        inputShell.wantsLayer = true
        inputShell.layer?.cornerRadius = 16
        inputShell.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.10).cgColor
        inputShell.layer?.borderWidth = 1
        inputShell.layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor

        inputField.isBordered = false
        inputField.isBezeled = false
        inputField.drawsBackground = false
        inputField.focusRingType = .none
        inputField.textColor = NSColor.white.withAlphaComponent(0.96)
        inputField.font = .systemFont(ofSize: 22, weight: .medium)
        inputField.placeholderString = "Ask anything"
        inputField.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setupLayout() {
        let stack = NSStackView(views: [titleLabel, inputShell, hintLabel])
        stack.orientation = .vertical
        stack.spacing = 10
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        inputShell.translatesAutoresizingMaskIntoConstraints = false
        inputShell.addSubview(inputField)
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -28),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),

            inputShell.widthAnchor.constraint(equalTo: stack.widthAnchor),
            inputShell.heightAnchor.constraint(equalToConstant: 52),

            inputField.leadingAnchor.constraint(equalTo: inputShell.leadingAnchor, constant: 16),
            inputField.trailingAnchor.constraint(equalTo: inputShell.trailingAnchor, constant: -16),
            inputField.centerYAnchor.constraint(equalTo: inputShell.centerYAnchor),
        ])
    }

    func focusInput() {
        window?.makeFirstResponder(inputField)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: GlassPanel?
    private var eventMonitor: Any?
    private var screenObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panel = GlassPanel()
        self.panel = panel
        placePanel(panel)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if let rootView = panel.contentView as? GlassRootView {
            rootView.focusInput()
        }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, let panel = self.panel else { return }
            self.placePanel(panel)
        }

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
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    private func placePanel(_ panel: NSPanel) {
        guard let screen = targetScreen() else { return }
        let visible = screen.visibleFrame
        let width = clamp(visible.width * 0.36, min: 460, max: 760)
        let height = clamp(visible.height * 0.11, min: 140, max: 170)
        let bottomInset = clamp(visible.height * 0.08, min: 48, max: 96)
        let x = visible.midX - (width / 2)
        let y = visible.minY + bottomInset
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }

    private func targetScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        if let hoveredScreen = NSScreen.screens.first(where: {
            NSMouseInRect(mouseLocation, $0.frame, false)
        }) {
            return hoveredScreen
        }
        return NSScreen.main ?? NSScreen.screens.first
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
