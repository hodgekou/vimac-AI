import AppKit
import SwiftUI
import VimacCore
import AXKit
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let log = Logger(subsystem: "dev.vimac-ai.Vimac", category: "app")
    private var statusItem: NSStatusItem?
    private var permissionMenuItem: NSMenuItem?
    private var permissionTimer: Timer?
    private var activationObserver: NSObjectProtocol?
    private let store = SettingsStore()
    private lazy var modes = ModeCoordinator(store: store)
    private var ignoreMenuItem: NSMenuItem?
    private var modeMenuItems: [(item: NSMenuItem, title: String, shortcut: KeyPath<VimacCore.Settings, Shortcut>)] = []
    private var settingsWindow: NSWindow?
    #if DEBUG
    private var debugTriggers: [DispatchSourceSignal] = []
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()

        if AXPermission.request() {
            permissionGranted()
        } else {
            log.notice("Accessibility permission missing, waiting for the user to grant it")
            waitForPermission()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
    }

    // MARK: Status item

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Vimac-AI")

        let menu = NSMenu()
        let permission = NSMenuItem(title: "", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        permission.target = self
        menu.addItem(permission)
        let hints = NSMenuItem(title: "Show Hints", action: #selector(showHints), keyEquivalent: "")
        hints.target = self
        menu.addItem(hints)
        modeMenuItems.append((hints, "Show Hints", \.hintShortcut))
        let search = NSMenuItem(title: "Search", action: #selector(searchMode), keyEquivalent: "")
        search.target = self
        menu.addItem(search)
        modeMenuItems.append((search, "Search", \.searchShortcut))
        let scroll = NSMenuItem(title: "Scroll Mode", action: #selector(scrollMode), keyEquivalent: "")
        scroll.target = self
        menu.addItem(scroll)
        modeMenuItems.append((scroll, "Scroll Mode", \.scrollShortcut))
        menu.addItem(.separator())
        let ignore = NSMenuItem(title: "", action: #selector(toggleIgnoreFrontmost), keyEquivalent: "")
        ignore.target = self
        menu.addItem(ignore)
        ignoreMenuItem = ignore
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.delegate = self
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Vimac-AI", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu

        statusItem = item
        permissionMenuItem = permission
        updatePermissionMenuItem(granted: AXPermission.isGranted)
    }

    private func updatePermissionMenuItem(granted: Bool) {
        permissionMenuItem?.title = granted
            ? "Accessibility: Granted"
            : "Grant Accessibility Permission…"
        permissionMenuItem?.isEnabled = !granted
    }

    /// Debug builds toggle a mode on a signal, so the modes can be driven from a terminal:
    /// `pkill -USR1 -x Vimac-AI` for hints, `pkill -USR2 -x Vimac-AI` for scrolling.
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
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(store: store)))
            window.title = "Vimac-AI Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        // An accessory application has to activate itself before its window can take the keyboard.
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
        observeFrontmostApplication()
        modes.start()
        installDebugTrigger()

        if let frontmost = NSWorkspace.shared.frontmostApplication {
            reportFocusedWindow(pid: frontmost.processIdentifier, name: frontmost.localizedName)
        }
    }

    // MARK: Frontmost application

    private func observeFrontmostApplication() {
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard let pid = application?.processIdentifier else { return }
            let name = application?.localizedName
            MainActor.assumeIsolated {
                self?.reportFocusedWindow(pid: pid, name: name)
            }
        }
    }

    /// Logs the role of the focused window of an application. This is the M0 proof that the accessibility path works.
    private func reportFocusedWindow(pid: pid_t, name: String?) {
        // An application must not query its own accessibility server.
        guard pid != ProcessInfo.processInfo.processIdentifier else { return }
        let log = log
        let name = name ?? "pid \(pid)"

        Task.detached(priority: .userInitiated) {
            let application = AXElement.application(pid: pid)
            application.setMessagingTimeout(seconds: 1)
            do {
                let role = try application.focusedWindow()?.role() ?? "none"
                log.notice("Focused window of \(name, privacy: .public): \(role, privacy: .public)")
            } catch {
                log.error("Could not read focused window of \(name, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
    }
}

extension AppDelegate: NSMenuDelegate {
    /// The frontmost application is still the one the user was in, because this app is an accessory.
    func menuWillOpen(_ menu: NSMenu) {
        // The shortcuts are user-defined, so they are shown as text rather than as key equivalents.
        let settings = store.effective
        for entry in modeMenuItems {
            entry.item.title = "\(entry.title)    \(settings[keyPath: entry.shortcut].displayString)"
        }

        guard let item = ignoreMenuItem else { return }
        let frontmost = NSWorkspace.shared.frontmostApplication
        guard let bundleID = frontmost?.bundleIdentifier,
              frontmost?.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            item.isHidden = true
            return
        }
        item.isHidden = false
        item.title = "Ignore \(frontmost?.localizedName ?? bundleID)"
        item.state = store.settings.ignoredBundleIDs.contains(bundleID) ? .on : .off
    }
}
