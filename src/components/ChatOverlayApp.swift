import AppKit
import Foundation

private struct ChatOverlayPayload: Decodable {
    let title: String?
    let status: String?
    let placeholder: String?
    let messages: [ChatMessage]?
    let conversationId: String?
    let agentBaseUrl: String?

    enum CodingKeys: String, CodingKey {
        case title, status, placeholder, messages
        case conversationId = "conversation_id"
        case agentBaseUrl = "agent_base_url"
    }

    static func fromStdin() -> ChatOverlayPayload {
        let data = FileHandle.standardInput.availableData
        guard !data.isEmpty else {
            return ChatOverlayPayload(
                title: nil,
                status: nil,
                placeholder: nil,
                messages: nil,
                conversationId: nil,
                agentBaseUrl: nil
            )
        }
        return (try? JSONDecoder().decode(ChatOverlayPayload.self, from: data))
            ?? ChatOverlayPayload(
                title: nil,
                status: nil,
                placeholder: nil,
                messages: nil,
                conversationId: nil,
                agentBaseUrl: nil
            )
    }
}

private struct ContinueAPIResponse: Decodable {
    let assistantMessage: String?
    let steps: [String]?

    enum CodingKeys: String, CodingKey {
        case assistantMessage = "assistant_message"
        case steps
    }
}

private enum ChatContinuation {
    static func captureScreen() -> Data? {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cua_\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "-t", "png", tempURL.path]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        return try? Data(contentsOf: tempURL)
    }

    static func post(
        baseURL: String,
        conversationId: String,
        prompt: String,
        chatPanel: NSWindow?,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let trimmedBase = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(trimmedBase)/conversation/\(conversationId)") else {
            DispatchQueue.main.async {
                completion(.failure(NSError(
                    domain: "ChatContinuation",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid agent URL."]
                )))
            }
            return
        }

        /// Keep the chat hidden after capture until success (terminate) or failure (show again).
        func restoreChatPanelForError() {
            chatPanel?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }

        chatPanel?.orderOut(nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let screenshotData = captureScreen()

            guard let screenshotData else {
                restoreChatPanelForError()
                completion(.failure(NSError(
                    domain: "ChatContinuation",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to capture screenshot."]
                )))
                return
            }

            let boundary = "CUABoundary\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
            var body = Data()

            func appendString(_ string: String) {
                if let data = string.data(using: .utf8) {
                    body.append(data)
                }
            }

            appendString("--\(boundary)\r\n")
            appendString("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n")
            appendString("\(prompt)\r\n")

            appendString("--\(boundary)\r\n")
            appendString("Content-Disposition: form-data; name=\"screenshot\"; filename=\"screenshot.png\"\r\n")
            appendString("Content-Type: image/png\r\n\r\n")
            body.append(screenshotData)
            appendString("\r\n--\(boundary)--\r\n")

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.httpBody = body

            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    if let error {
                        restoreChatPanelForError()
                        completion(.failure(error))
                        return
                    }

                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                    guard statusCode == 200 || statusCode == 202 else {
                        restoreChatPanelForError()
                        completion(.failure(NSError(
                            domain: "ChatContinuation",
                            code: statusCode,
                            userInfo: [NSLocalizedDescriptionKey: "Agent returned HTTP \(statusCode)."]
                        )))
                        return
                    }

                    guard let data, !data.isEmpty else {
                        completion(.success(""))
                        return
                    }

                    if let decoded = try? JSONDecoder().decode(ContinueAPIResponse.self, from: data) {
                        if let message = decoded.assistantMessage?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !message.isEmpty {
                            completion(.success(message))
                            return
                        }
                        if let steps = decoded.steps, !steps.isEmpty {
                            completion(.success(steps.joined(separator: "\n")))
                            return
                        }
                    }

                    completion(.success(""))
                }
            }.resume()
        }
    }
}

private enum ChatOverlayTeardown {
    /// Send-and-forget: tear down all UI once the server accepts the request.
    static func closeAllWindowsAndTerminate() {
        NSApp.windows.forEach { window in
            window.orderOut(nil)
            window.close()
        }
        NSApp.terminate(nil)
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

        controller.onSubmit = { [weak self, weak controller] text in
            guard let self, let controller else { return }

            controller.appendMessage(ChatMessage(role: "user", text: text))
            controller.contentView.clearInput()

            guard
                let convId = self.payload.conversationId,
                let base = self.payload.agentBaseUrl,
                !convId.isEmpty,
                !base.isEmpty
            else {
                return
            }

            controller.setBusy(true)
            controller.setStatus("Sending…")

            ChatContinuation.post(
                baseURL: base,
                conversationId: convId,
                prompt: text,
                chatPanel: controller.panel
            ) { result in
                switch result {
                case .success:
                    ChatOverlayTeardown.closeAllWindowsAndTerminate()
                case .failure(let error):
                    controller.setBusy(false)
                    controller.setStatus("Error: \(error.localizedDescription)")
                }
            }
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
