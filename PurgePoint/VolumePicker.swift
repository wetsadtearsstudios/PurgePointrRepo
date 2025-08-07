import SwiftUI

struct VolumePicker: View {
    @State private var showingOpenPanel = false

    var body: some View {
        Button(action: {
            openVolumePicker()
        }) {
            Label("Select Volume…", systemImage: "externaldrive")
        }
    }

    private func openVolumePicker() {
        print("DEBUG: openVolumePicker called")

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.title = "Select Volume(s) to Wipe"
        panel.message = "Choose one or more volumes (not root '/')"
        panel.prompt = "Select"
        panel.directoryURL = URL(fileURLWithPath: "/Volumes")

        panel.begin { response in
            if response == .OK {
                let selectedURLs = panel.urls
                print("DEBUG: openPanel selected URLs: \(selectedURLs)")

                let filtered = selectedURLs
                    .map { $0.path == "/" ? URL(fileURLWithPath: "/System/Volumes/Data") : $0 }
                    .filter { $0.path != "/" } // prevent any lingering root entries

                if filtered.isEmpty {
                    print("⚠️ No valid volumes selected.")
                    return
                }

                SettingsManager.shared.clearVolumeBookmarks()
                SettingsManager.shared.saveVolumeBookmarks(filtered)

                let paths = Set(filtered.map(\.path))
                SettingsManager.shared.selectedVolumes = paths
            } else {
                print("DEBUG: openPanel cancelled or failed")
            }
        }
    }
}
