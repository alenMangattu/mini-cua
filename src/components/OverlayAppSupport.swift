import AppKit

/// Picks the screen the mouse is currently on, falling back sensibly.
/// Shared by every overlay controller so positioning behaviour stays consistent.
func overlayTargetScreen() -> NSScreen? {
    let mouse = NSEvent.mouseLocation
    return NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
        ?? NSScreen.main
        ?? NSScreen.screens.first
}

/// Wraps the `didChangeScreenParametersNotification` observer so every
/// controller doesn't have to re-implement add/remove bookkeeping.
final class OverlayScreenObserver {
    private var token: NSObjectProtocol?

    init(onChange: @escaping () -> Void) {
        token = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { _ in onChange() }
    }

    deinit {
        if let token {
            NotificationCenter.default.removeObserver(token)
        }
    }
}

/// Installs a local key-down monitor that terminates the app when Esc is
/// pressed. Every one-shot overlay binary needs exactly this behaviour.
final class OverlayEscMonitor {
    private var monitor: Any?

    func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                NSApp.terminate(nil)
                return nil
            }
            return event
        }
    }

    func remove() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    deinit { remove() }
}

/// Single place that boots an overlay binary:
/// configures `NSApplication`, installs the Esc monitor, runs the event loop.
enum OverlayAppRunner {
    static func run(_ delegate: NSApplicationDelegate) {
        let app = NSApplication.shared
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
