import AppKit

struct ChatMessage: Decodable {
    let role: String
    let text: String
}

final class ChatMessageRow: NSView {
    private let bubble = NSView()
    private let label = NSTextField(wrappingLabelWithString: "")
    private let isUser: Bool

    init(message: ChatMessage) {
        self.isUser = message.role.lowercased() == "user"
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setup(text: message.text)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setup(text: String) {
        wantsLayer = true

        bubble.wantsLayer = true
        bubble.translatesAutoresizingMaskIntoConstraints = false
        bubble.layer?.cornerRadius = 11
        bubble.layer?.cornerCurve = .continuous
        bubble.layer?.backgroundColor = bubbleBackground().cgColor
        bubble.layer?.borderWidth = 1
        bubble.layer?.borderColor = bubbleBorder().cgColor

        label.translatesAutoresizingMaskIntoConstraints = false
        label.stringValue = text
        label.textColor = NSColor.white.withAlphaComponent(0.94)
        label.font = .systemFont(ofSize: 11, weight: .regular)
        label.maximumNumberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.isSelectable = true

        bubble.addSubview(label)
        addSubview(bubble)

        let leading = bubble.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: isUser ? 48 : 0)
        let trailing = bubble.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: isUser ? 0 : -48)
        let alignEdge = isUser
            ? bubble.trailingAnchor.constraint(equalTo: trailingAnchor)
            : bubble.leadingAnchor.constraint(equalTo: leadingAnchor)

        NSLayoutConstraint.activate([
            bubble.topAnchor.constraint(equalTo: topAnchor),
            bubble.bottomAnchor.constraint(equalTo: bottomAnchor),
            leading,
            trailing,
            alignEdge,

            label.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -6),
            label.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -10),
        ])
    }

    private func bubbleBackground() -> NSColor {
        isUser
            ? NSColor.white.withAlphaComponent(0.18)
            : NSColor.black.withAlphaComponent(0.22)
    }

    private func bubbleBorder() -> NSColor {
        isUser
            ? NSColor.white.withAlphaComponent(0.14)
            : NSColor.white.withAlphaComponent(0.08)
    }
}
