# InputSoundSwitcher

A macOS menu bar app for quickly switching audio input devices. Built to solve the Bluetooth headset quality problem — when a BT headset connects, macOS routes both input and output to it, forcing the low-quality HFP/SCO codec instead of high-quality A2DP. This app makes it easy to switch input back to the built-in mic.

## Features

- **Menu bar icon** with current input device name — click to switch between input devices
- **Global hotkey** (Cmd+Shift+M) — opens a floating picker from anywhere
- **Auto-detect Bluetooth headset connection** — pops up the picker so you can choose your input device
- **Auto-detect call start** — when a call starts (Slack, Teams, etc.) with Bluetooth output and non-Bluetooth input, shows the picker as a reminder
- **Launch at login** — optional, via Settings

## Requirements

- macOS 13.0 (Ventura) or later
- Swift 5.9+ (included with Xcode Command Line Tools)

## Install

### One-liner

```bash
curl -fsSL https://raw.githubusercontent.com/michlo23/InputSoundSwitcher/main/install.sh | bash
```

### Homebrew

```bash
brew install michlo23/tap/inputsoundswitcher
cp -r $(brew --prefix)/InputSoundSwitcher.app /Applications/
```

### Build from source

No Xcode required — just Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/michlo23/InputSoundSwitcher.git
cd InputSoundSwitcher
./build.sh
```

All methods install to `/Applications/`. Then run:

```bash
open /Applications/InputSoundSwitcher.app
```

### First launch

macOS may show a security prompt since the app isn't signed. Go to **System Settings > Privacy & Security** and click "Open Anyway".

## Usage

| Action | How |
|---|---|
| Switch input device | Click menu bar icon, select device |
| Quick picker | Press Cmd+Shift+M |
| Settings | Click menu bar icon > Settings… |
| Quit | Click menu bar icon > Quit |

The app runs as an agent (no Dock icon). To enable launch at login, open Settings from the menu bar dropdown.

## How it works

- Uses **CoreAudio** C APIs to enumerate input devices, get/set the system default, and listen for device changes
- Monitors `kAudioDevicePropertyDeviceIsRunningSomewhere` to detect when a call app starts using the mic
- Monitors device list changes to detect Bluetooth headset connections
- Uses the [HotKey](https://github.com/soffes/HotKey) library for the global keyboard shortcut
- Not sandboxed (required for `AudioObjectSetPropertyData` to change the system default input)

## License

MIT
