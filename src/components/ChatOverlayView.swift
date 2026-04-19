import AppKit

final class ChatOverlayView: NSVisualEffectView {
    var onSubmit: ((String) -> Void)?

    private let titleLabel: NSTextField
    private let statusLabel: NSTextField
    private let contrastTint = NSView()
    private let messagesStack = NSStackView()
    private let messagesScrollView = NSScrollView()
    private let messagesContainer = NSView()
    private let inputShell = NSView()
    private let inputField = NSTextField()

    init(title: String, status: String, placeholder: String) {
        self.titleLabel = NSTextField(labelWithString: title)
        self.statusLabel = NSTextField(labelWithString: status)
        super.init(frame: ChatOverlayMetrics.baseFrame)

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

        setupChrome(placeholder: placeholder)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func focusInput() {
        window?.makeFirstResponder(inputField)
    }

    func setTitle(_ text: String) {
        titleLabel.stringValue = text
    }

    func setStatus(_ text: String, alpha: CGFloat = 0.60) {
        statusLabel.stringValue = text
        statusLabel.textColor = NSColor.white.withAlphaComponent(alpha)
    }

    func setPlaceholder(_ text: String) {
        inputField.placeholderString = text
    }

    func setBusy(_ busy: Bool) {
        inputField.isEnabled = !busy
    }

    func clearInput() {
        inputField.stringValue = ""
    }

    func setMessages(_ messages: [ChatMessage]) {
        messagesStack.arrangedSubviews.forEach { view in
            messagesStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for message in messages {
            let row = ChatMessageRow(message: message)
            messagesStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: messagesStack.widthAnchor).isActive = true
        }

        DispatchQueue.main.async { [weak self] in
            self?.scrollToBottom()
        }
    }

    func appendMessage(_ message: ChatMessage) {
        let row = ChatMessageRow(message: message)
        messagesStack.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: messagesStack.widthAnchor).isActive = true
        DispatchQueue.main.async { [weak self] in
            self?.scrollToBottom()
        }
    }

    private func scrollToBottom() {
        guard let documentView = messagesScrollView.documentView else { return }
        let bottom = NSPoint(x: 0, y: max(0, documentView.bounds.height - messagesScrollView.contentView.bounds.height))
        messagesScrollView.contentView.scroll(to: bottom)
        messagesScrollView.reflectScrolledClipView(messagesScrollView.contentView)
    }

    private func setupChrome(placeholder: String) {
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = NSColor.white.withAlphaComponent(0.96)

        statusLabel.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
        statusLabel.textColor = NSColor.white.withAlphaComponent(0.55)

        contrastTint.wantsLayer = true
        contrastTint.layer?.cornerRadius = OverlayMetrics.panelCornerRadius
        contrastTint.layer?.cornerCurve = .continuous
        contrastTint.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.10).cgColor

        messagesStack.orientation = .vertical
        messagesStack.spacing = 6
        messagesStack.alignment = .leading
        messagesStack.translatesAutoresizingMaskIntoConstraints = false

        messagesContainer.translatesAutoresizingMaskIntoConstraints = false
        messagesContainer.addSubview(messagesStack)

        messagesScrollView.drawsBackground = false
        messagesScrollView.borderType = .noBorder
        messagesScrollView.hasVerticalScroller = true
        messagesScrollView.autohidesScrollers = true
        messagesScrollView.translatesAutoresizingMaskIntoConstraints = false
        messagesScrollView.wantsLayer = true
        messagesScrollView.layer?.cornerRadius = OverlayMetrics.inputCornerRadius
        messagesScrollView.layer?.cornerCurve = .continuous
        messagesScrollView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.08).cgColor
        messagesScrollView.layer?.borderWidth = 1
        messagesScrollView.layer?.borderColor = NSColor.white.withAlphaComponent(0.06).cgColor
        messagesScrollView.documentView = messagesContainer

        inputShell.wantsLayer = true
        inputShell.translatesAutoresizingMaskIntoConstraints = false
        inputShell.layer?.cornerRadius = OverlayMetrics.inputCornerRadius
        inputShell.layer?.cornerCurve = .continuous
        inputShell.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.18).cgColor
        inputShell.layer?.borderWidth = 1
        inputShell.layer?.borderColor = NSColor.white.withAlphaComponent(0.10).cgColor

        inputField.isBordered = false
        inputField.isBezeled = false
        inputField.drawsBackground = false
        inputField.focusRingType = .none
        inputField.textColor = NSColor.white.withAlphaComponent(0.96)
        inputField.font = .systemFont(ofSize: 12, weight: .medium)
        inputField.placeholderString = placeholder
        inputField.translatesAutoresizingMaskIntoConstraints = false
        inputField.delegate = self
    }

    private func setupLayout() {
        let stack = NSStackView(views: [titleLabel, messagesScrollView, inputShell, statusLabel])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        contrastTint.translatesAutoresizingMaskIntoConstraints = false
        inputShell.addSubview(inputField)
        addSubview(contrastTint)
        addSubview(stack)

        NSLayoutConstraint.activate([
            contrastTint.leadingAnchor.constraint(equalTo: leadingAnchor),
            contrastTint.trailingAnchor.constraint(equalTo: trailingAnchor),
            contrastTint.topAnchor.constraint(equalTo: topAnchor),
            contrastTint.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),

            messagesScrollView.widthAnchor.constraint(equalTo: stack.widthAnchor),

            messagesContainer.leadingAnchor.constraint(equalTo: messagesScrollView.contentView.leadingAnchor),
            messagesContainer.trailingAnchor.constraint(equalTo: messagesScrollView.contentView.trailingAnchor),
            messagesContainer.topAnchor.constraint(equalTo: messagesScrollView.contentView.topAnchor),
            messagesContainer.widthAnchor.constraint(equalTo: messagesScrollView.contentView.widthAnchor),

            messagesStack.leadingAnchor.constraint(equalTo: messagesContainer.leadingAnchor, constant: 10),
            messagesStack.trailingAnchor.constraint(equalTo: messagesContainer.trailingAnchor, constant: -10),
            messagesStack.topAnchor.constraint(equalTo: messagesContainer.topAnchor, constant: 10),
            messagesStack.bottomAnchor.constraint(equalTo: messagesContainer.bottomAnchor, constant: -10),

            inputShell.widthAnchor.constraint(equalTo: stack.widthAnchor),
            inputShell.heightAnchor.constraint(equalToConstant: 34),

            inputField.leadingAnchor.constraint(equalTo: inputShell.leadingAnchor, constant: 12),
            inputField.trailingAnchor.constraint(equalTo: inputShell.trailingAnchor, constant: -12),
            inputField.centerYAnchor.constraint(equalTo: inputShell.centerYAnchor),
        ])
    }

    private func submit() {
        let text = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        onSubmit?(text)
    }
}

extension ChatOverlayView: NSTextFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            submit()
            return true
        }
        return false
    }
}

enum ChatOverlayMetrics {
    static let baseFrame = NSRect(x: 0, y: 0, width: OverlayMetrics.baseFrame.width, height: 260)
}
