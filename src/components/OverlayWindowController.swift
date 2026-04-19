import AppKit

final class OverlayWindowController {
    let contentView: OverlayContentView
    let panel: OverlayPanel

    var onSubmit: ((String) -> Void)? {
        didSet { contentView.onSubmit = onSubmit }
    }

    private var screenObserver: OverlayScreenObserver?
    private var isShowingResponse = false

    init(
        title: String = "CUA",
        status: String = "Press Enter to submit  ·  Esc to close",
        placeholder: String = "Ask anything…"
    ) {
        self.contentView = OverlayContentView(title: title, status: status, placeholder: placeholder)
        self.panel = OverlayPanel(rootView: contentView)
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
        focusInput()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func focusInput() {
        contentView.focusInput()
    }

    func setTitle(_ text: String) {
        contentView.setTitle(text)
    }

    func setStatus(_ text: String, alpha: CGFloat = 0.60) {
        contentView.setStatus(text, alpha: alpha)
    }

    func setPlaceholder(_ text: String) {
        contentView.setPlaceholder(text)
    }

    func setBusy(_ busy: Bool) {
        contentView.setBusy(busy)
    }

    func clearInput() {
        contentView.clearInput()
    }

    func inputText() -> String {
        contentView.currentInput()
    }

    func setResponse(_ text: String?) {
        let hasResponse = !(text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        isShowingResponse = hasResponse
        contentView.setResponse(text)
        reposition()
    }

    func reposition() {
        guard let screen = overlayTargetScreen() else { return }
        let visible = screen.visibleFrame
        let width = clamp(visible.width * 0.30, min: 380, max: 620)
        let heightMultiplier: CGFloat = isShowingResponse ? 0.18 : 0.095
        let minHeight: CGFloat = isShowingResponse ? 230 : 120
        let maxHeight: CGFloat = isShowingResponse ? 300 : 148
        let height = clamp(visible.height * heightMultiplier, min: minHeight, max: maxHeight)
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
