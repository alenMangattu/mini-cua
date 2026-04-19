import AppKit

final class DemoAppDelegate: NSObject, NSApplicationDelegate {
    private var overlayController: OverlayWindowController?
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = OverlayWindowController(
            title: "CUA",
            status: "Press Enter to demo  ·  Esc to close",
            placeholder: "Ask anything…"
        )
        controller.onSubmit = { [weak controller] _ in
            controller?.setBusy(false)
            controller?.clearInput()
            controller?.setResponse(nil)
            controller?.setStatus("Ready  ·  Hook your own handler later")
            controller?.focusInput()
        }

        overlayController = controller
        controller.show()

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                NSApp.terminate(nil)
                return nil
            }
            return event
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }
}

@main
struct GlassOverlayApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = DemoAppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
