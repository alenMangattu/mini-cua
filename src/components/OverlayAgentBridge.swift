import AppKit

private let kAgentURL = URL(string: "http://127.0.0.1:8000/agent/run")!

enum OverlayAgentBridge {
    static func submit(prompt: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let previousAlpha = NSApp.keyWindow?.alphaValue ?? 1
        NSApp.keyWindow?.alphaValue = 0

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let screenshotData = captureScreen()
            NSApp.keyWindow?.alphaValue = previousAlpha
            NSApp.activate(ignoringOtherApps: true)

            guard let screenshotData else {
                completion(.failure(NSError(
                    domain: "OverlayAgentBridge",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to capture screenshot."]
                )))
                return
            }

            post(prompt: trimmed, screenshotData: screenshotData, completion: completion)
        }
    }

    private static func captureScreen() -> Data? {
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

    private static func post(prompt: String, screenshotData: Data, completion: @escaping (Result<Void, Error>) -> Void) {
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

        var request = URLRequest(url: kAgentURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let error {
                    completion(.failure(error))
                    return
                }

                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                if statusCode == 200 || statusCode == 202 {
                    completion(.success(()))
                } else {
                    completion(.failure(NSError(
                        domain: "OverlayAgentBridge",
                        code: statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "Agent server returned HTTP \(statusCode)."]
                    )))
                }
            }
        }.resume()
    }
}
