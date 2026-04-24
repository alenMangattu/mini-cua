import AppKit

final class ChatOverlayController {
    let contentView: ChatOverlayView
    let panel: OverlayPanel

    var onSubmit: ((String) -> Void)? {
        didSet { contentView.onSubmit = onSubmit }
    }

    private var screenObserver: OverlayScreenObserver?

    init(
        title: String = "Chat",
        status: String = "Press Enter to send  ·  Esc to close",
        placeholder: String = "Type a message…"
    ) {
        self.contentView = ChatOverlayView(title: title, status: status, placeholder: placeholder)
        self.panel = OverlayPanel(rootView: contentView, frame: ChatOverlayMetrics.baseFrame)

        self.contentView.onSubmit = { [weak self] text in
            self?.onSubmit?(text)
        }

        screenObserver = OverlayScreenObserver { [weak self] in
            self?.reposition()
        }
    }

    func show() {
        reposition()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        contentView.focusInput()
    }

    func setMessages(_ messages: [ChatMessage]) {
        contentView.setMessages(messages)
    }

    func appendMessage(_ message: ChatMessage) {
        contentView.appendMessage(message)
    }

    func setTitle(_ text: String) { contentView.setTitle(text) }
    func setStatus(_ text: String) { contentView.setStatus(text) }
    func setBusy(_ busy: Bool) { contentView.setBusy(busy) }

    private func reposition() {
        guard let screen = overlayTargetScreen() else { return }
        let visible = screen.visibleFrame
        let width = clamp(visible.width * 0.30, min: 380, max: 620)
        let height = clamp(visible.height * 0.26, min: 220, max: 340)
        let bottomInset = clamp(visible.height * 0.06, min: 32, max: 72)

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
}
