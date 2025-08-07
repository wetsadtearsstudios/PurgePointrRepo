import SwiftUI

struct StatusMenu: View {
    @ObservedObject var wipeManager = WipeManager()
    @ObservedObject var settings = SettingsManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PurgePoint")
                .font(.headline)

            Divider()

            ForEach(Array(settings.resolvedVolumePaths), id: \.self) { path in
                HStack {
                    Text(URL(fileURLWithPath: path).lastPathComponent)
                        .lineLimit(1)
                    Spacer()
                    Text(wipeManager.currentFreeSpaceInGB(forPath: path))
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            Button(action: wipeManager.overwriteFreeSpace) {
                HStack {
                    if wipeManager.isWiping {
                        ProgressView(value: wipeManager.wipeProgress, total: 100)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(width: 100)
                    } else {
                        Text("Wipe Free Space")
                    }
                }
            }
            .disabled(wipeManager.isWiping)

            VolumePicker()

            Divider()

            SettingsWindow()
                .frame(height: 120)

            if !wipeManager.lastLogOutput.isEmpty {
                Divider()
                ScrollView {
                    Text(wipeManager.lastLogOutput)
                        .font(.caption)
                        .padding(.top, 5)
                }
                .frame(height: 100)
            }
        }
        .padding(12)
        .frame(width: 300)
    }
}
