//
//  WipeManager.swift   (FULL FILE)
//  PurgePoint
//

import Foundation
import Combine
import UserNotifications

class WipeManager: ObservableObject {

    // ───────────────────────────── Published state
    @Published var isWiping      = false
    @Published var wipeProgress  = 0.0            // 0…100

    // ───────────────────────────── Internals
    private var task: Process?
    private(set) var lastLogOutput = ""

    // MARK: – ENTRY POINT
    func overwriteFreeSpace() {

        // ❶ Resolve stored security-scoped bookmarks … and rewrite “/” ➜ Data-volume
        var pairs: [(url: URL, displayName: String)] = []

        for (origURL, data) in SettingsManager.shared.volumeBookmarks {
            var isStale = false
            do {
                var resolved = try URL(
                    resolvingBookmarkData: data,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                let display: String
                if resolved.path == "/" {                       // user picked “Macintosh HD”
                    print("📦 Rewriting bookmark “/” → “/System/Volumes/Data”")
                    resolved = URL(fileURLWithPath: "/System/Volumes/Data")
                    display  = "/"                              // nice name in UI / logs
                } else {
                    display  = resolved.lastPathComponent
                }
                pairs.append((resolved, display))

            } catch {
                appendLog("❌ Couldn’t resolve bookmark for \(origURL.path): \(error.localizedDescription)")
            }
        }

        let dbg = pairs.map { "\($0.displayName) ↦ \($0.url.path)" }.joined(separator: ", ")
        print("📌 Bookmarks queued for wiping: [\(dbg)]")

        startWiping(pairs: pairs)
    }

    // MARK: – HIGH-LEVEL WIPE LOOP
    private func startWiping(pairs: [(url: URL, displayName: String)]) {

        isWiping      = true
        wipeProgress  = 0
        lastLogOutput = ""
        print("🚀 Starting wipe …")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            for (url, label) in pairs {

                print("🔍 Preparing “\(label)” (actual path: \(url.path))")

                var scopedGranted = false
                if url.startAccessingSecurityScopedResource() {
                    scopedGranted = true
                    print("✅ Security-scoped access granted for \(label)")
                } else {
                    let warn = "⚠️ Couldn’t obtain security scope for \(label); trying anyway."
                    self.appendLog(warn); print(warn)
                }

                self.doWipe(atResolvedURL: url, displayName: label)

                if scopedGranted { url.stopAccessingSecurityScopedResource() }
            }

            DispatchQueue.main.async {
                self.isWiping = false
                self.wipeProgress = 0
                self.sendCompletionNotification()
                print("✅ All wipe tasks finished.")
            }
        }
    }

    // MARK: – LOW-LEVEL WIPE
    private func doWipe(atResolvedURL url: URL, displayName: String) {

        // ❷ Decide *where* we create the “bigfilefill” folder
        var workingRoot = url
        if url.path == "/System/Volumes/Data" {                 // protected top level
            workingRoot = url.appendingPathComponent("Users/Shared")
            print("🔒 Data-volume root detected → switching to \(workingRoot.path)")
        }

        let dir      = workingRoot.appendingPathComponent("PurgePointFill")
        let junkPath = dir.appendingPathComponent("junk").path

        // Create temp dir
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            print("📁 Created directory \(dir.path)")
        } catch {
            let msg = "❌ Can’t create folder on \(displayName): \(error.localizedDescription)"
            appendLog(msg); print(msg); return
        }

        // Assemble dd command
        let proc        = Process()
        task            = proc
        proc.launchPath = "/bin/dd"
        let inputDev    = SettingsManager.shared.useSecureErase ? "/dev/urandom" : "/dev/zero"
        proc.arguments  = ["if=\(inputDev)", "of=\(junkPath)", "bs=32m", "status=progress", "oflag=direct"]

        // Optional 2 GB buffer
        var totalBytes = 0
        if SettingsManager.shared.leaveSafetyBuffer {
            let writableMB = max(calculateWritableMegabytes(for: workingRoot.path) - 2048, 1)
            totalBytes     = writableMB * 1_048_576
            proc.arguments?.append("count=\(writableMB)")
            print("➕ count=\(writableMB) MB (leave 2 GB head-room)")
        }

        print("▶️ Running dd with args: \(proc.arguments!.joined(separator: " "))")

        // Pipe for progress / log
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError  = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] h in
            guard let self,
                  let str = String(data: h.availableData, encoding: .utf8),
                  !str.isEmpty else { return }

            DispatchQueue.main.async { self.lastLogOutput += str }

            if
                let r = str.range(of: "(\\d+) bytes", options: .regularExpression),
                let written = Int(str[r].replacingOccurrences(of: " bytes", with: "")),
                totalBytes > 0
            {
                let pct = min(100, Double(written) / Double(totalBytes) * 100)
                DispatchQueue.main.async { self.wipeProgress = pct }
            }
        }

        // Run
        do {
            try proc.run()
            proc.waitUntilExit()
            print("✅ dd completed for \(displayName)")
        } catch {
            let msg = "❌ Failed to start dd on \(displayName): \(error.localizedDescription)"
            appendLog(msg); print(msg); return
        }

        // Clean-up
        try? FileManager.default.removeItem(atPath: junkPath)
        try? FileManager.default.removeItem(at: dir)
        appendLog("✅ Overwrite complete on \(displayName)")
    }

    // MARK: – Helpers
    private func appendLog(_ s: String) {
        DispatchQueue.main.async { self.lastLogOutput += s + "\n" }
    }

    func currentFreeSpaceInGB(forPath path: String) -> String {
        do {
            let bytes = try URL(fileURLWithPath: path)
                .resourceValues(forKeys: [.volumeAvailableCapacityKey])
                .volumeAvailableCapacity ?? 0
            return String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
        } catch {
            print("❌ Free-space error for \(path): \(error)")
            return "Unknown"
        }
    }

    private func calculateWritableMegabytes(for path: String) -> Int {
        (try? URL(fileURLWithPath: path)
            .resourceValues(forKeys: [.volumeAvailableCapacityKey])
            .volumeAvailableCapacity)
            .map { Int($0 / 1_048_576) } ?? 1
    }

    private func sendCompletionNotification() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { ok, _ in
            guard ok else { return }
            let c = UNMutableNotificationContent()
            c.title    = "Purge Complete"
            c.subtitle = "Free-space overwrite finished"
            c.sound    = .default
            UNUserNotificationCenter.current()
                .add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
        }
    }

    func cancelWipe() {
        task?.terminate()
        isWiping = false
        print("🛑 User cancelled wipe.")
    }
}
