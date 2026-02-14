import CoreAudio
import Foundation

struct AudioDevice: Identifiable, Equatable, Hashable {
    let id: AudioDeviceID
    let name: String
    let uid: String
    let inputChannelCount: Int
    let transportType: UInt32

    var isBluetooth: Bool {
        transportType == kAudioDeviceTransportTypeBluetooth
            || transportType == kAudioDeviceTransportTypeBluetoothLE
    }

    var abbreviatedName: String {
        let maxLength = 20
        let prefixes = ["MacBook Pro ", "MacBook Air ", "MacBook "]
        var shortened = name
        for prefix in prefixes {
            if shortened.hasPrefix(prefix) {
                shortened = String(shortened.dropFirst(prefix.count))
                break
            }
        }
        if shortened.count > maxLength {
            shortened = String(shortened.prefix(maxLength - 1)) + "…"
        }
        return shortened
    }

    static func == (lhs: AudioDevice, rhs: AudioDevice) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
