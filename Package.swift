// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Vimac-AI",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Vimac-AI", targets: ["VimacApp"]),
    ],
    targets: [
        // Pure logic. Depends on Foundation only so it can be tested without any permission.
        .target(name: "VimacCore"),
        // Accessibility (AXUIElement) access.
        .target(name: "AXKit", dependencies: ["VimacCore"]),
        // Event taps, activators, synthesized mouse and scroll events.
        .target(name: "InputKit", dependencies: ["VimacCore"]),
        // Transparent per-screen panels that draw hints and borders.
        .target(name: "OverlayKit", dependencies: ["VimacCore"]),
        // On-device recognition of text that the accessibility tree does not expose.
        .target(name: "ScreenVision"),
        .executableTarget(
            name: "VimacApp",
            dependencies: ["VimacCore", "AXKit", "InputKit", "OverlayKit", "ScreenVision"]
        ),
        .testTarget(name: "VimacCoreTests", dependencies: ["VimacCore"]),
    ],
    swiftLanguageModes: [.v6]
)
