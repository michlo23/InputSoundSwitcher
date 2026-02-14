import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var hotKeyManager: HotKeyManager
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        toggleLaunchAtLogin(newValue)
                    }
            }

            Section("Keyboard Shortcut") {
                LabeledContent("Open device picker") {
                    Text(hotKeyManager.currentKeyCombo)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary)
                        .cornerRadius(6)
                        .font(.system(.body, design: .monospaced))
                }
            }

            Section {
                HStack {
                    Spacer()
                    Text("InputSoundSwitcher")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 350, height: 200)
    }

    private func toggleLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to \(enable ? "enable" : "disable") launch at login: \(error)")
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
