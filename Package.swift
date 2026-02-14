// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "InputSoundSwitcher",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey.git", from: "0.2.1"),
    ],
    targets: [
        .executableTarget(
            name: "InputSoundSwitcher",
            dependencies: ["HotKey"],
            path: "InputSoundSwitcher",
            exclude: ["Info.plist", "InputSoundSwitcher.entitlements"],
            linkerSettings: [
                .linkedFramework("CoreAudio"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
    ]
)
