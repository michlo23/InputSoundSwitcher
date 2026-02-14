import SwiftUI

@main
struct InputSoundSwitcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(audioManager: appDelegate.audioManager) {
                openSettingsWindow()
            }
        } label: {
            Label(
                appDelegate.audioManager.currentInputDevice?.abbreviatedName ?? "Mic",
                systemImage: "mic.fill"
            )
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(hotKeyManager: appDelegate.hotKeyManager)
        }
    }

    private func openSettingsWindow() {
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var audioManager = AudioDeviceManager()
    let hotKeyManager = HotKeyManager()
    private var floatingPanel: FloatingPickerPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        hotKeyManager.onHotKeyPressed = { [weak self] in
            self?.toggleFloatingPicker()
        }
        audioManager.onBluetoothMicInUse = { [weak self] in
            self?.showFloatingPicker()
        }
        audioManager.onBluetoothDeviceConnected = { [weak self] _ in
            self?.showFloatingPicker()
        }
    }

    private func toggleFloatingPicker() {
        if let panel = floatingPanel, panel.isVisible {
            panel.dismissPicker()
            return
        }
        showFloatingPicker()
    }

    private func showFloatingPicker() {
        // Dismiss existing panel if visible
        floatingPanel?.dismissPicker()

        let pickerView = DevicePickerView(audioManager: audioManager) { [weak self] in
            self?.floatingPanel?.dismissPicker()
        }
        let hostingView = NSHostingView(rootView: pickerView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 300)

        let panel = FloatingPickerPanel(hostingView: hostingView)
        let fittingSize = hostingView.fittingSize
        panel.setContentSize(fittingSize)
        self.floatingPanel = panel
        panel.showPicker()
    }
}
