// SPDX-License-Identifier: GPL-3.0-only

#if DEBUG
import AppKit
import SwiftUI
import KeyfariCore

/// Renders the settings panes off screen, for checking the layout during development.
@MainActor
enum SettingsSnapshot {
    static func render(to directory: URL) {
        _ = NSApplication.shared
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // A throwaway defaults domain, so the user's settings are neither read nor changed.
        let suite = "app.keyfari.Keyfari.snapshot"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        let store = SettingsStore(defaults: defaults)
        // Two entries, one of them not installed, so both kinds of row are drawn.
        store.settings.ignoredBundleIDs = ["com.apple.Terminal", "com.example.missing"]

        for language in [AppLanguage.english, .chinese, .japanese] {
            store.settings.language = language
            for pane in SettingsPane.allCases {
                let navigation = SettingsNavigation()
                navigation.pane = pane
                let host = NSHostingView(rootView: SettingsView(store: store, navigation: navigation))
                host.frame = NSRect(origin: .zero, size: host.fittingSize)

                // A window gives the view an appearance and a backing scale to draw with.
                let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
                window.contentView = host
                host.layoutSubtreeIfNeeded()

                guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { continue }
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let url = directory.appendingPathComponent("settings-\(language.rawValue)-\(pane.rawValue).png")
                try? bitmap.representation(using: .png, properties: [:])?.write(to: url)
            }
        }
        defaults.removePersistentDomain(forName: suite)
    }
}
#endif
