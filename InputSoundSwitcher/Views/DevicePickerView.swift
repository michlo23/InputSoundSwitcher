import SwiftUI

struct DevicePickerView: View {
    @ObservedObject var audioManager: AudioDeviceManager
    var onDeviceSelected: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Select Input Device")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            if audioManager.inputDevices.isEmpty {
                Text("No input devices found")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            } else {
                ForEach(audioManager.inputDevices) { device in
                    DeviceRow(
                        device: device,
                        isSelected: device == audioManager.currentInputDevice
                    ) {
                        audioManager.setDefaultInputDevice(device)
                        onDeviceSelected()
                    }
                }
            }
        }
        .padding(.bottom, 8)
        .frame(width: 320)
    }
}

private struct DeviceRow: View {
    let device: AudioDevice
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.system(size: 14))

                Text(device.name)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(isHovered ? Color.primary.opacity(0.1) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .padding(.horizontal, 4)
    }
}
