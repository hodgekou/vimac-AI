// swift-tools-version: 6.0
// SPDX-License-Identifier: GPL-3.0-only

import PackageDescription

let package = Package(
    name: "Keyfari",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Keyfari", targets: ["KeyfariApp"])
    ],
    targets: [
        // Pure logic. Depends on Foundation only so it can be tested without any permission.
        .target(name: "KeyfariCore"),
        // Accessibility (AXUIElement) access.
        .target(name: "AXKit", dependencies: ["KeyfariCore"]),
        // Event taps, activators, synthesized mouse and scroll events.
        .target(name: "InputKit", dependencies: ["KeyfariCore"]),
        // Transparent per-screen panels that draw hints and borders.
        .target(name: "OverlayKit", dependencies: ["KeyfariCore"]),
        // On-device recognition of text that the accessibility tree does not expose.
        .target(name: "ScreenVision"),
        .executableTarget(
            name: "KeyfariApp",
            dependencies: ["KeyfariCore", "AXKit", "InputKit", "OverlayKit", "ScreenVision"]
        ),
        .testTarget(name: "KeyfariCoreTests", dependencies: ["KeyfariCore"]),
    ],
    swiftLanguageModes: [.v6]
)
