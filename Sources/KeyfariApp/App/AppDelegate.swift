// SPDX-License-Identifier: GPL-3.0-only

import AXKit
import AppKit
import KeyfariCore
import ScreenVision
import SwiftUI
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let log = Logger(subsystem: "app.keyfari.Keyfari", category: "app")
    private var statusItem: NSStatusItem?
    private var permissionMenuItem: NSMenuItem?
    private var permissionTimer: Timer?
    private let store = SettingsStore()
    private lazy var modes = ModeCoordinator(store: store)
    private var ignoreMenuItem: NSMenuItem?
    private var settingsMenuItem: NSMenuItem?
    private var quitMenuItem: NSMenuItem?
    private var modeMenuItems: [(item: NSMenuItem, title: String, shortcut: KeyPath<KeyfariCore.Settings, Shortcut>)] = []
    private var settingsWindow: NSWindow?
    #if DEBUG
    private var debugTriggers: [DispatchSourceSignal] = []
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Alerts and the settings window then show the real icon too.
        NSApp.applicationIconImage = Brand.icon
        setUpStatusItem()
        #if DEBUG
        // `--open-settings` opens the settings window at launch, for checking it without clicking through the menu.
        if CommandLine.arguments.contains("--open-settings") {
            openSettings()
        }
        #endif

        if AXPermission.request() {
            permissionGranted()
        } else {
            log.notice("Accessibility permission missing, waiting for the user to grant it")
            waitForPermission()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
    }

    /// Loads the text recognition models in the background, so the first activation does not wait for them.
    private func warmUpTextDetection() {
        guard store.effective.visionMode != .off else { return }
        let log = log
        Task.detached(priority: .utility) {
            let started = ContinuousClock.now
            await ScreenTextDetector.warmUp()
            let elapsed = ContinuousClock.now - started
            log.notice("Text detection warmed up after \(elapsed.description, privacy: .public)")
        }
    }

    // MARK: Status item

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Keyfari")

        let menu = NSMenu()
        let permission = NSMenuItem(title: "", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        permission.target = self
        menu.addItem(permission)
        let hints = NSMenuItem(title: "Show Hints", action: #selector(showHints), keyEquivalent: "")
        hints.image = Self.menuSymbol("tag.fill")
        hints.target = self
        menu.addItem(hints)
        modeMenuItems.append((hints, "Show Hints", \.hintShortcut))
        let search = NSMenuItem(title: "Search", action: #selector(searchMode), keyEquivalent: "")
        search.image = Self.menuSymbol("magnifyingglass")
        search.target = self
        menu.addItem(search)
        modeMenuItems.append((search, "Search", \.searchShortcut))
        let scroll = NSMenuItem(title: "Scroll Mode", action: #selector(scrollMode), keyEquivalent: "")
        scroll.image = Self.menuSymbol("arrow.up.arrow.down")
        scroll.target = self
        menu.addItem(scroll)
        modeMenuItems.append((scroll, "Scroll Mode", \.scrollShortcut))
        menu.addItem(.separator())
        let ignore = NSMenuItem(title: "", action: #selector(toggleIgnoreFrontmost), keyEquivalent: "")
        ignore.image = Self.menuSymbol("nosign")
        ignore.target = self
        menu.addItem(ignore)
        ignoreMenuItem = ignore
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.image = Self.menuSymbol("gearshape")
        settings.target = self
        menu.addItem(settings)
        settingsMenuItem = settings
        menu.delegate = self
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Keyfari", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        quitMenuItem = quit
        item.menu = menu

        statusItem = item
        permissionMenuItem = permission
        updatePermissionMenuItem(granted: AXPermission.isGranted)
    }

    private func updatePermissionMenuItem(granted: Bool) {
        permissionMenuItem?.title =
            granted
            ? tr("Accessibility: Granted")
            : tr("Grant Accessibility Permission…")
        permissionMenuItem?.isEnabled = !granted
    }

    /// Debug builds toggle a mode on a signal, so the modes can be driven from a terminal:
    /// `pkill -USR1 -x Keyfari` for hints, `pkill -USR2 -x Keyfari` for scrolling.
    private func installDebugTrigger() {
        #if DEBUG
        debugTriggers = [(SIGUSR1, Mode.hint), (SIGUSR2, Mode.scroll)].map { number, mode in
            signal(number, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
            source.setEventHandler { [weak self] in
                MainActor.assumeIsolated { self?.modes.toggle(mode) }
            }
            source.resume()
            return source
        }
        #endif
    }

    private static func menuSymbol(_ name: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }

    @objc private func showHints() {
        modes.toggle(.hint)
    }

    @objc private func searchMode() {
        modes.toggle(.search)
    }

    @objc private func scrollMode() {
        modes.toggle(.scroll)
    }

    @objc private func toggleIgnoreFrontmost() {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return }
        store.toggleIgnored(bundleID: bundleID)
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let content = SettingsView(store: store, navigation: SettingsNavigation())
            let window = NSWindow(contentViewController: NSHostingController(rootView: content))
            window.title = tr("Keyfari Settings")
            // The content runs under a transparent title bar, so the sidebar reaches the top edge.
            window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        // While the window is open the app shows in the Dock and in the application switcher,
        // so the window can be found again after another application covers it.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: Permission

    private func waitForPermission() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, AXPermission.isGranted else { return }
                self.permissionTimer?.invalidate()
                self.permissionTimer = nil
                self.permissionGranted()
            }
        }
    }

    private func permissionGranted() {
        log.notice("Accessibility permission granted")
        updatePermissionMenuItem(granted: true)
        modes.start()
        installDebugTrigger()
        warmUpTextDetection()
    }
}

extension AppDelegate: NSMenuDelegate {
    /// The frontmost application is still the one the user was in, because this app is an accessory.
    func menuWillOpen(_ menu: NSMenu) {
        // The shortcuts are user-defined, so they are shown as text rather than as key equivalents.
        let settings = store.effective
        for entry in modeMenuItems {
            entry.item.title = "\(tr(entry.title))    \(settings[keyPath: entry.shortcut].displayString)"
        }
        settingsMenuItem?.title = tr("Settings…")
        quitMenuItem?.title = tr("Quit Keyfari")
        updatePermissionMenuItem(granted: AXPermission.isGranted)

        guard let item = ignoreMenuItem else { return }
        let frontmost = NSWorkspace.shared.frontmostApplication
        guard let bundleID = frontmost?.bundleIdentifier,
            frontmost?.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else {
            item.isHidden = true
            return
        }
        item.isHidden = false
        item.title = tr("Ignore %@", frontmost?.localizedName ?? bundleID)
        item.state = store.settings.ignoredBundleIDs.contains(bundleID) ? .on : .off
    }
}

extension AppDelegate: NSWindowDelegate {
    /// Back to a menu bar app once the settings window is gone.
    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === settingsWindow else { return }
        ShortcutRecording.shared.stop()
        NSApp.setActivationPolicy(.accessory)
    }
}
