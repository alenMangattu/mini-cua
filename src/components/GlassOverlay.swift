import AppKit

// MARK: - Helpers

private func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
    min(max(value, minValue), maxValue)
}

private let kAgentURL = URL(string: "http://127.0.0.1:8000/agent/run")!

// MARK: - Panel

final class GlassPanel: NSPanel {
    private let panelCornerRadius: CGFloat = 28

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
        hasShadow = false
        level = .statusBar
        isFloatingPanel = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        animationBehavior = .utilityWindow
        contentView = GlassRootView(frame: frame)
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
        contentView?.layer?.cornerRadius = panelCornerRadius
        contentView?.layer?.cornerCurve = .continuous
        contentView?.layer?.masksToBounds = true
        contentView?.layer?.backgroundColor = NSColor.clear.cgColor

        if let frameView = contentView?.superview {
            frameView.wantsLayer = true
            frameView.layer?.backgroundColor = NSColor.clear.cgColor

            let roundedPath = CGPath(
                roundedRect: frameView.bounds,
                cornerWidth: panelCornerRadius,
                cornerHeight: panelCornerRadius,
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

// MARK: - Root view

final class GlassRootView: NSVisualEffectView {
    private let titleLabel  = NSTextField(labelWithString: "CUA")
    private let statusLabel = NSTextField(labelWithString: "Press Enter to run  ·  Esc to close")
    private let contrastTint = NSView()
    private let inputShell  = NSView()
    private let inputField  = NSTextField()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .sidebar
        blendingMode = .behindWindow
        state = .active
        isEmphasized = true
        appearance = NSAppearance(named: .vibrantDark)
        wantsLayer = true

        if let layer {
            layer.cornerRadius = 28
            layer.cornerCurve = .continuous
            layer.masksToBounds = true
            layer.borderWidth = 1
            layer.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
            layer.backgroundColor = NSColor.black.withAlphaComponent(0.04).cgColor
        }

        setupLabels()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: Setup

    private func setupLabels() {
        titleLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        titleLabel.textColor = NSColor.white.withAlphaComponent(0.96)

        statusLabel.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = NSColor.white.withAlphaComponent(0.60)

        contrastTint.wantsLayer = true
        contrastTint.layer?.cornerRadius = 28
        contrastTint.layer?.cornerCurve = .continuous
        contrastTint.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.10).cgColor

        inputShell.wantsLayer = true
        inputShell.layer?.cornerRadius = 16
        inputShell.layer?.cornerCurve = .continuous
        inputShell.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.14).cgColor
        inputShell.layer?.borderWidth = 1
        inputShell.layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor

        inputField.isBordered = false
        inputField.isBezeled = false
        inputField.drawsBackground = false
        inputField.focusRingType = .none
        inputField.textColor = NSColor.white.withAlphaComponent(0.96)
        inputField.font = .systemFont(ofSize: 22, weight: .medium)
        inputField.placeholderString = "Ask anything…"
        inputField.translatesAutoresizingMaskIntoConstraints = false
        inputField.delegate = self
    }

    private func setupLayout() {
        let stack = NSStackView(views: [titleLabel, inputShell, statusLabel])
        stack.orientation = .vertical
        stack.spacing = 10
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        contrastTint.translatesAutoresizingMaskIntoConstraints = false
        inputShell.translatesAutoresizingMaskIntoConstraints = false
        inputShell.addSubview(inputField)
        addSubview(contrastTint)
        addSubview(stack)

        NSLayoutConstraint.activate([
            contrastTint.leadingAnchor.constraint(equalTo: leadingAnchor),
            contrastTint.trailingAnchor.constraint(equalTo: trailingAnchor),
            contrastTint.topAnchor.constraint(equalTo: topAnchor),
            contrastTint.bottomAnchor.constraint(equalTo: bottomAnchor),

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

    // MARK: Status helpers

    private func setStatus(_ text: String, alpha: CGFloat = 0.60) {
        statusLabel.stringValue = text
        statusLabel.textColor = NSColor.white.withAlphaComponent(alpha)
    }

    private func setBusy(_ busy: Bool) {
        inputField.isEnabled = !busy
    }

    // MARK: Screenshot

    /// Captures the main display as PNG data using the system screencapture tool.
    /// Works on all macOS versions and surfaces the Screen Recording permission prompt automatically.
    private func captureScreen() -> Data? {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cua_\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        // -x  suppress sound  -t png  force PNG format
        proc.arguments = ["-x", "-t", "png", tempURL.path]

        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return nil
        }

        return try? Data(contentsOf: tempURL)
    }

    // MARK: Submit

    private func submit() {
        let prompt = inputField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !prompt.isEmpty else { return }

        setBusy(true)
        setStatus("Capturing screen…")

        // Hide the panel briefly so it doesn't appear in the screenshot.
        window?.orderOut(nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self else { return }

            let screenshotData = self.captureScreen()

            guard let screenshotData else {
                self.window?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                self.setStatus("Screenshot failed — press Esc to close", alpha: 0.80)
                self.setBusy(false)
                return
            }

            self.setStatus("Sending to agent…")
            self.postToAgent(prompt: prompt, screenshotData: screenshotData)
        }
    }

    // MARK: Network

    private func postToAgent(prompt: String, screenshotData: Data) {
        let boundary = "CUABoundary\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        var body = Data()

        func appendString(_ s: String) {
            if let d = s.data(using: .utf8) { body.append(d) }
        }

        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n")
        appendString("\(prompt)\r\n")

        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"screenshot\"; filename=\"screenshot.png\"\r\n")
        appendString("Content-Type: image/png\r\n\r\n")
        body.append(screenshotData)
        appendString("\r\n--\(boundary)--\r\n")

        var request = URLRequest(url: kAgentURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.setBusy(false)
                if let error {
                    self.window?.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                    self.setStatus("Error: \(error.localizedDescription)", alpha: 0.80)
                } else {
                    let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                    if code == 200 {
                        NSApp.terminate(nil)
                    } else {
                        self.window?.makeKeyAndOrderFront(nil)
                        NSApp.activate(ignoringOtherApps: true)
                        self.setStatus("Agent returned HTTP \(code) — Esc to close", alpha: 0.80)
                    }
                }
            }
        }.resume()
    }
}

// MARK: - NSTextFieldDelegate

extension GlassRootView: NSTextFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            submit()
            return true
        }
        return false
    }
}

// MARK: - App delegate

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
        (panel.contentView as? GlassRootView)?.focusInput()

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, let panel = self.panel else { return }
            self.placePanel(panel)
        }

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { NSApp.terminate(nil); return nil }
            return event
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }

    private func placePanel(_ panel: NSPanel) {
        guard let screen = targetScreen() else { return }
        let visible = screen.visibleFrame
        let width   = clamp(visible.width  * 0.36, min: 460, max: 760)
        let height  = clamp(visible.height * 0.11, min: 140, max: 170)
        let bottomInset = clamp(visible.height * 0.08, min: 48, max: 96)
        panel.setFrame(
            NSRect(x: visible.midX - width / 2, y: visible.minY + bottomInset, width: width, height: height),
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

// MARK: - Entry point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
