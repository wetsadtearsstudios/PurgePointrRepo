import Cocoa
import Combine

class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private let wipeManager = WipeManager()
    private let settings = SettingsManager.shared
    private let settingsWindow = SettingsWindowController()
    private var cancellables = Set<AnyCancellable>()

    private let eraserIcon = NSImage(systemSymbolName: "eraser.fill", accessibilityDescription: "PurgePoint")
    private let progressIcon = NSImage(systemSymbolName: "hourglass", accessibilityDescription: "Wiping")

    private var wipeItem: NSMenuItem!
    private var progressItem: NSMenuItem!
    private var spaceItem: NSMenuItem!

    private var liveUpdateTimer: Timer?

    override init() {
        super.init()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = eraserIcon

        let menu = NSMenu()
        menu.delegate = self

        wipeItem = NSMenuItem(title: "🧽 Overwrite Free Space", action: #selector(runWipe), keyEquivalent: "")
        wipeItem.target = self
        menu.addItem(wipeItem)

        spaceItem = NSMenuItem(title: "💾 Free space: calculating...", action: nil, keyEquivalent: "")
        spaceItem.isEnabled = false
        menu.addItem(spaceItem)

        progressItem = NSMenuItem(title: "⌛ Wiping in progress...", action: nil, keyEquivalent: "")
        progressItem.isEnabled = false
        progressItem.isHidden = true
        menu.addItem(progressItem)

        menu.addItem(NSMenuItem.separator())

        let volumesItem = NSMenuItem(title: "💽 Choose Volumes to Wipe…", action: #selector(openVolumePicker), keyEquivalent: "")
        volumesItem.target = self
        menu.addItem(volumesItem)

        menu.addItem(NSMenuItem.separator())

        if !hasFullDiskAccess() {
            let fullDiskItem = NSMenuItem(title: "🔐 Grant Full Disk Access…", action: #selector(openPrivacyPane), keyEquivalent: "")
            fullDiskItem.target = self
            menu.addItem(fullDiskItem)
        }

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "⚙️ Settings…", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let viewLogItem = NSMenuItem(title: "📜 View Last Log", action: #selector(showLastLog), keyEquivalent: "")
        viewLogItem.target = self
        menu.addItem(viewLogItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit PurgePoint", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu

        wipeManager.$isWiping
            .receive(on: RunLoop.main)
            .sink { [weak self] isWiping in
                guard let self = self else { return }
                self.wipeItem.isEnabled = !isWiping
                self.progressItem.isHidden = !isWiping
                self.statusItem.button?.image = isWiping ? self.progressIcon : self.eraserIcon

                if !isWiping {
                    self.notifyWipeCompleted()
                }
            }
            .store(in: &cancellables)

        wipeManager.$wipeProgress
            .receive(on: RunLoop.main)
            .sink { [weak self] progress in
                guard let self = self else { return }
                if self.wipeManager.isWiping {
                    self.progressItem.title = String(format: "⌛ Wiping in progress… %.2f%%", progress)
                }
            }
            .store(in: &cancellables)
    }

    private func hasFullDiskAccess() -> Bool {
        return FileManager.default.isReadableFile(atPath: "/Library/Application Support")
    }

    @objc func runWipe() {
        let selected = settings.resolvedVolumePaths
        print("DEBUG: runWipe triggered. resolvedVolumePaths = \(selected)")

        guard !selected.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "No volume selected"
            alert.informativeText = "Please choose at least one volume to wipe."
            alert.alertStyle = .informational
            alert.runModal()
            return
        }

        let alert = NSAlert()
        alert.messageText = "Are you sure?"
        alert.informativeText = "This will overwrite free space on the following volumes:\n\n" +
            selected.joined(separator: "\n")
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Proceed")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            print("DEBUG: User confirmed wipe. Proceeding.")
            wipeManager.overwriteFreeSpace()
        } else {
            print("DEBUG: User cancelled wipe.")
        }
    }

    @objc func openSettings() {
        settingsWindow.show()
    }

    @objc func openPrivacyPane() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc func openVolumePicker() {
        let panel = NSOpenPanel()
        panel.title = "Select Volumes for Free Space Overwrite"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = URL(fileURLWithPath: "/Volumes")

        panel.begin { [weak self] response in
            guard response == .OK, let self = self else { return }

            let selected = panel.urls.compactMap { url -> URL? in
                if url.path == "/" {
                    return URL(fileURLWithPath: "/System/Volumes/Data")
                }
                return url
            }

            SettingsManager.shared.clearVolumeBookmarks()
            self.settings.saveVolumeBookmarks(selected)
        }
    }

    @objc func showLastLog() {
        let alert = NSAlert()
        alert.messageText = "Last Wipe Log"
        alert.informativeText = wipeManager.lastLogOutput.isEmpty ? "No log available." : wipeManager.lastLogOutput
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func notifyWipeCompleted() {
        let notification = NSUserNotification()
        notification.title = "Purge Complete"
        notification.informativeText = "The free space wipe has finished."
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
}

extension MenuBarController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        if let selectedVolume = settings.resolvedVolumePaths.first {
            let space = wipeManager.currentFreeSpaceInGB(forPath: selectedVolume)
            spaceItem.title = "💾 Current selected volume: \(selectedVolume) — \(space)"
        } else {
            spaceItem.title = "💾 No volume selected"
        }

        // Live updating timer while menu is open
        liveUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.wipeManager.isWiping {
                let progress = self.wipeManager.wipeProgress
                self.progressItem.title = String(format: "⌛ Wiping in progress… %.2f%%", progress)
                self.statusItem.menu?.update()
            }
        }
        RunLoop.main.add(liveUpdateTimer!, forMode: .common)
    }

    func menuDidClose(_ menu: NSMenu) {
        liveUpdateTimer?.invalidate()
        liveUpdateTimer = nil
    }
}
