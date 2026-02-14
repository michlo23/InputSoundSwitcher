import SwiftUI

struct MenuBarView: View {
    @ObservedObject var audioManager: AudioDeviceManager
    var onOpenSettings: () -> Void

    var body: some View {
        ForEach(audioManager.inputDevices) { device in
            let isCurrent = device == audioManager.currentInputDevice
            Button {
                audioManager.setDefaultInputDevice(device)
            } label: {
                HStack {
                    Text(device.name)
                    Spacer()
                    if isCurrent {
                        Text("✓")
                    }
                }
            }
        }

        Divider()

        Button("Settings…") {
            onOpenSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
