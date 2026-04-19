import AppKit

final class OverlayContentView: NSVisualEffectView {
    var onSubmit: ((String) -> Void)?

    private let titleLabel: NSTextField
    private let statusLabel: NSTextField
    private let contrastTint = NSView()
    private let inputShell = NSView()
    private let inputField = NSTextField()
    private let responseScrollView = NSScrollView()
    private let responseTextView = NSTextView()
    private var responseHeightConstraint: NSLayoutConstraint?

    init(title: String, status: String, placeholder: String) {
        self.titleLabel = NSTextField(labelWithString: title)
        self.statusLabel = NSTextField(labelWithString: status)
        super.init(frame: OverlayMetrics.baseFrame)

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

        setupLabels(placeholder: placeholder)
        setupLayout()
        setResponse(nil)
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

    func currentInput() -> String {
        inputField.stringValue
    }

    func setResponse(_ text: String?) {
        let hasResponse = !(text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        responseTextView.string = text ?? ""
        responseHeightConstraint?.constant = hasResponse ? 100 : 0
        responseScrollView.isHidden = !hasResponse
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    private func setupLabels(placeholder: String) {
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = NSColor.white.withAlphaComponent(0.96)

        statusLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        statusLabel.textColor = NSColor.white.withAlphaComponent(0.60)

        contrastTint.wantsLayer = true
        contrastTint.layer?.cornerRadius = OverlayMetrics.panelCornerRadius
        contrastTint.layer?.cornerCurve = .continuous
        contrastTint.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.10).cgColor

        inputShell.wantsLayer = true
        inputShell.layer?.cornerRadius = OverlayMetrics.inputCornerRadius
        inputShell.layer?.cornerCurve = .continuous
        inputShell.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.14).cgColor
        inputShell.layer?.borderWidth = 1
        inputShell.layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor

        inputField.isBordered = false
        inputField.isBezeled = false
        inputField.drawsBackground = false
        inputField.focusRingType = .none
        inputField.textColor = NSColor.white.withAlphaComponent(0.96)
        inputField.font = .systemFont(ofSize: 18, weight: .medium)
        inputField.placeholderString = placeholder
        inputField.translatesAutoresizingMaskIntoConstraints = false
        inputField.delegate = self

        responseScrollView.drawsBackground = false
        responseScrollView.borderType = .noBorder
        responseScrollView.hasVerticalScroller = true
        responseScrollView.autohidesScrollers = true
        responseScrollView.translatesAutoresizingMaskIntoConstraints = false
        responseScrollView.wantsLayer = true
        responseScrollView.layer?.cornerRadius = OverlayMetrics.inputCornerRadius
        responseScrollView.layer?.cornerCurve = .continuous
        responseScrollView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.08).cgColor
        responseScrollView.layer?.borderWidth = 1
        responseScrollView.layer?.borderColor = NSColor.white.withAlphaComponent(0.06).cgColor

        responseTextView.drawsBackground = false
        responseTextView.isEditable = false
        responseTextView.isSelectable = true
        responseTextView.textColor = NSColor.white.withAlphaComponent(0.92)
        responseTextView.font = .systemFont(ofSize: 13, weight: .regular)
        responseTextView.textContainerInset = NSSize(width: 10, height: 8)
        responseScrollView.documentView = responseTextView
    }

    private func setupLayout() {
        let stack = NSStackView(views: [titleLabel, inputShell, responseScrollView, statusLabel])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        contrastTint.translatesAutoresizingMaskIntoConstraints = false
        inputShell.translatesAutoresizingMaskIntoConstraints = false
        inputShell.addSubview(inputField)
        addSubview(contrastTint)
        addSubview(stack)

        responseHeightConstraint = responseScrollView.heightAnchor.constraint(equalToConstant: 0)
        responseHeightConstraint?.isActive = true

        NSLayoutConstraint.activate([
            contrastTint.leadingAnchor.constraint(equalTo: leadingAnchor),
            contrastTint.trailingAnchor.constraint(equalTo: trailingAnchor),
            contrastTint.topAnchor.constraint(equalTo: topAnchor),
            contrastTint.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),

            inputShell.widthAnchor.constraint(equalTo: stack.widthAnchor),
            inputShell.heightAnchor.constraint(equalToConstant: 44),

            inputField.leadingAnchor.constraint(equalTo: inputShell.leadingAnchor, constant: 14),
            inputField.trailingAnchor.constraint(equalTo: inputShell.trailingAnchor, constant: -14),
            inputField.centerYAnchor.constraint(equalTo: inputShell.centerYAnchor),
        ])
    }

    private func submit() {
        let prompt = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        onSubmit?(prompt)
    }
}

extension OverlayContentView: NSTextFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            submit()
            return true
        }
        return false
    }
}
