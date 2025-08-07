import SwiftUI

struct SettingsWindow: View {
    @ObservedObject var settings = SettingsManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("PurgePoint Settings")
                .font(.headline)
                .padding(.bottom, 5)

            Toggle("Use Secure Wipe (Random Data)", isOn: $settings.useSecureErase)
            Toggle("Leave 2 GB of Free Space", isOn: $settings.leaveSafetyBuffer)

            Spacer()
        }
        .padding(20)
        .frame(width: 320)
    }
}
