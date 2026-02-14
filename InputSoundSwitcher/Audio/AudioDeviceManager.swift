import CoreAudio
import Foundation
import Combine

final class AudioDeviceManager: ObservableObject {
    @Published var inputDevices: [AudioDevice] = []
    @Published var currentInputDevice: AudioDevice?

    /// Fires when a Bluetooth mic starts being used (e.g. call started)
    var onBluetoothMicInUse: (() -> Void)?
    /// Fires when a new Bluetooth input device connects
    var onBluetoothDeviceConnected: ((_ deviceName: String) -> Void)?

    private var debounceWorkItem: DispatchWorkItem?
    private let debounceInterval: TimeInterval = 0.3

    /// Device ID we're currently monitoring for "is running" changes
    private var monitoredDeviceID: AudioDeviceID = 0
    /// Track previous running state to detect transitions
    private var wasRunning = false
    /// Cooldown to avoid repeated popups during same call session
    private var lastPromptDate: Date = .distantPast
    private let promptCooldown: TimeInterval = 30
    /// Track known device UIDs to detect new connections
    private var knownDeviceUIDs: Set<String> = []
    /// Skip detection on first launch
    private var initialRefreshDone = false

    private static let hiddenTransportTypes: Set<UInt32> = [
        kAudioDeviceTransportTypeAggregate,
        kAudioDeviceTransportTypeVirtual,
    ]

    init() {
        refreshDevices()
        installListeners()
    }

    deinit {
        removeListeners()
        removeRunningListener()
    }

    // MARK: - Public

    func setDefaultInputDevice(_ device: AudioDevice) {
        var deviceID = device.id
        NSLog("Setting default input device to: %@ (id: %d)", device.name, deviceID)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &deviceID
        )
        if status == noErr {
            NSLog("Successfully set default input device to: %@", device.name)
        } else {
            NSLog("Failed to set default input device: %d", status)
        }
    }

    // MARK: - Device Enumeration

    func refreshDevices() {
        let allDeviceIDs = getAllDeviceIDs()
        var devices: [AudioDevice] = []

        for deviceID in allDeviceIDs {
            let transportType = getTransportType(for: deviceID)
            if Self.hiddenTransportTypes.contains(transportType) {
                continue
            }

            guard let device = makeAudioDevice(from: deviceID, transportType: transportType),
                  device.inputChannelCount > 0 else { continue }

            devices.append(device)
        }

        let currentID = getDefaultInputDeviceID()
        let newUIDs = Set(devices.map(\.uid))

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            // Detect newly connected Bluetooth input devices
            if self.initialRefreshDone {
                let addedUIDs = newUIDs.subtracting(self.knownDeviceUIDs)
                if !addedUIDs.isEmpty {
                    let newBTDevices = devices.filter { addedUIDs.contains($0.uid) && $0.isBluetooth }
                    if let firstBT = newBTDevices.first {
                        NSLog("Bluetooth input device connected: %@", firstBT.name)
                        self.onBluetoothDeviceConnected?(firstBT.name)
                    }
                }
            }

            self.knownDeviceUIDs = newUIDs
            self.initialRefreshDone = true
            self.inputDevices = devices
            self.currentInputDevice = devices.first(where: { $0.id == currentID })
            self.updateRunningMonitor(deviceID: currentID)
        }
    }

    private func getAllDeviceIDs() -> [AudioDeviceID] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )
        guard status == noErr, dataSize > 0 else { return [] }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )
        guard status == noErr else { return [] }
        return deviceIDs
    }

    private func makeAudioDevice(from deviceID: AudioDeviceID, transportType: UInt32) -> AudioDevice? {
        guard let name = getDeviceName(for: deviceID),
              let uid = getDeviceUID(for: deviceID) else { return nil }
        let channelCount = getInputChannelCount(for: deviceID)
        return AudioDevice(
            id: deviceID,
            name: name,
            uid: uid,
            inputChannelCount: channelCount,
            transportType: transportType
        )
    }

    private func getDeviceName(for deviceID: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, &name)
        guard status == noErr, let cfName = name?.takeUnretainedValue() else { return nil }
        return cfName as String
    }

    private func getDeviceUID(for deviceID: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, &uid)
        guard status == noErr, let cfUID = uid?.takeUnretainedValue() else { return nil }
        return cfUID as String
    }

    private func getInputChannelCount(for deviceID: AudioDeviceID) -> Int {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)
        guard status == noErr, dataSize > 0 else { return 0 }

        let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(dataSize))
        defer { bufferListPointer.deallocate() }

        status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, bufferListPointer)
        guard status == noErr else { return 0 }

        let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
        var channelCount = 0
        for buffer in bufferList {
            channelCount += Int(buffer.mNumberChannels)
        }
        return channelCount
    }

    private func getTransportType(for deviceID: AudioDeviceID) -> UInt32 {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var transportType: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, &transportType)
        guard status == noErr else { return 0 }
        return transportType
    }

    private func getDefaultInputDeviceID() -> AudioDeviceID {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioDeviceID = 0
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceID
        )
        guard status == noErr else { return 0 }
        return deviceID
    }

    private func isDeviceRunning(_ deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var isRunning: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, &isRunning)
        guard status == noErr else { return false }
        return isRunning != 0
    }

    // MARK: - Device List Listeners

    private func installListeners() {
        var devicesAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &devicesAddress,
            nil,
            deviceListChanged
        )

        var defaultInputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultInputAddress,
            nil,
            deviceListChanged
        )
    }

    private func removeListeners() {
        var devicesAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &devicesAddress,
            nil,
            deviceListChanged
        )

        var defaultInputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultInputAddress,
            nil,
            deviceListChanged
        )
    }

    private lazy var deviceListChanged: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
        self?.debouncedRefresh()
    }

    private func debouncedRefresh() {
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.refreshDevices()
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
    }

    // MARK: - Mic-in-use Monitoring

    /// Watch the current default input device for "is running somewhere" changes.
    /// When the default device switches, we re-attach the listener to the new device.
    private func updateRunningMonitor(deviceID: AudioDeviceID) {
        guard deviceID != monitoredDeviceID else { return }
        removeRunningListener()
        monitoredDeviceID = deviceID
        wasRunning = isDeviceRunning(deviceID)
        installRunningListener()
    }

    private func installRunningListener() {
        guard monitoredDeviceID != 0 else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(
            monitoredDeviceID,
            &address,
            nil,
            runningStateChanged
        )
    }

    private func removeRunningListener() {
        guard monitoredDeviceID != 0 else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            monitoredDeviceID,
            &address,
            nil,
            runningStateChanged
        )
    }

    private lazy var runningStateChanged: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
        DispatchQueue.main.async {
            self?.handleRunningStateChange()
        }
    }

    private func handleRunningStateChange() {
        let running = isDeviceRunning(monitoredDeviceID)
        let justStarted = running && !wasRunning
        wasRunning = running

        guard justStarted else { return }

        // Prompt when: output is Bluetooth but input is NOT Bluetooth
        // (user has BT headphones for listening, but mic routing needs attention)
        let outputIsBluetooth = isDefaultOutputBluetooth()
        let inputIsBluetooth = currentInputDevice?.isBluetooth ?? false

        guard outputIsBluetooth && !inputIsBluetooth else { return }
        guard Date().timeIntervalSince(lastPromptDate) > promptCooldown else { return }

        NSLog("Call started: output is Bluetooth, input is '%@' (not BT) — prompting",
              currentInputDevice?.name ?? "unknown")
        lastPromptDate = Date()
        onBluetoothMicInUse?()
    }

    private func isDefaultOutputBluetooth() -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioDeviceID = 0
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceID
        )
        guard status == noErr else { return false }
        let transport = getTransportType(for: deviceID)
        return transport == kAudioDeviceTransportTypeBluetooth
            || transport == kAudioDeviceTransportTypeBluetoothLE
    }
}
