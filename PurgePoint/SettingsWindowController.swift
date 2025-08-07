import AppKit
import SwiftUI

class SettingsWindowController {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsWindow())
            window = NSWindow(contentViewController: hosting)
            window?.styleMask = [.titled, .closable]
            window?.title = "Settings"
            window?.isReleasedWhenClosed = false
            window?.center()
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
