import AppKit

private struct HelloOverlayPayload {
    let title: String
    let status: String
    let message: String

    static func fromCommandLine() -> HelloOverlayPayload {
        let args = Array(CommandLine.arguments.dropFirst())
        let title = args.indices.contains(0) ? args[0] : "Hello"
        let status = args.indices.contains(1) ? args[1] : "Opened from Python"
        let message = args.indices.contains(2) ? args[2] : "Hello world from Python."
        return HelloOverlayPayload(title: title, status: status, message: message)
    }
}

final class HelloOverlayAppDelegate: NSObject, NSApplicationDelegate {
    private var controller: OverlayWindowController?
    private let escMonitor = OverlayEscMonitor()
    private let payload = HelloOverlayPayload.fromCommandLine()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = OverlayWindowController(
            title: payload.title,
            status: payload.status,
            placeholder: "Press Esc to close"
        )
        self.controller = controller
        controller.setResponse(payload.message)
        controller.show()

        escMonitor.install()
    }

    func applicationWillTerminate(_ notification: Notification) {
        escMonitor.remove()
    }
}

@main
struct HelloOverlayApp {
    static func main() {
        OverlayAppRunner.run(HelloOverlayAppDelegate())
    }
}
