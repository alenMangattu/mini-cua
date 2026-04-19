import AppKit
import Foundation

private struct ChatOverlayPayload: Decodable {
    let title: String?
    let status: String?
    let placeholder: String?
    let messages: [ChatMessage]?

    static func fromStdin() -> ChatOverlayPayload {
        let data = FileHandle.standardInput.availableData
        guard !data.isEmpty else {
            return ChatOverlayPayload(title: nil, status: nil, placeholder: nil, messages: nil)
        }
        return (try? JSONDecoder().decode(ChatOverlayPayload.self, from: data))
            ?? ChatOverlayPayload(title: nil, status: nil, placeholder: nil, messages: nil)
    }
}

final class ChatOverlayAppDelegate: NSObject, NSApplicationDelegate {
    private var controller: ChatOverlayController?
    private let escMonitor = OverlayEscMonitor()
    private let payload = ChatOverlayPayload.fromStdin()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = ChatOverlayController(
            title: payload.title ?? "Chat",
            status: payload.status ?? "Press Enter to send  ·  Esc to close",
            placeholder: payload.placeholder ?? "Type a message…"
        )
        self.controller = controller

        controller.onSubmit = { [weak controller] text in
            controller?.appendMessage(ChatMessage(role: "user", text: text))
            controller?.contentView.clearInput()
        }

        controller.setMessages(payload.messages ?? [])
        controller.show()

        escMonitor.install()
    }

    func applicationWillTerminate(_ notification: Notification) {
        escMonitor.remove()
    }
}

@main
struct ChatOverlayApp {
    static func main() {
        OverlayAppRunner.run(ChatOverlayAppDelegate())
    }
}
