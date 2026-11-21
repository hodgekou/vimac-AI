import AppKit
import AXKit
import InputKit
import os
import OverlayKit
import VimacCore

enum Mode: Equatable {
    case hint
    case search
    case scroll
}

/// Owns the global shortcuts and makes sure at most one mode is active.
@MainActor
final class ModeCoordinator {
    /// The global shortcut of each mode, from the settings in force.
    private var shortcuts: [(mode: Mode, shortcut: Shortcut)] = []

    private let log = Logger(subsystem: "dev.vimac-ai.Vimac", category: "mode")
    private let store: SettingsStore
    private let hotkeys = GlobalHotkeys()
    private let overlay = OverlayController()
    private let interceptor = KeyInterceptor()
    private let labelMemory = LabelMemory()
    private var holdKey: HoldKeyActivator?
    private var keySequence: KeySequenceActivator?
    private var active: (mode: Mode, stop: @MainActor () -> Void)?

    init(store: SettingsStore) {
        self.store = store
    }

    /// Registers the shortcuts. Call once the Accessibility permission is granted.
    func start() {
        store.onChange = { [weak self] in self?.applySettings() }
        applySettings()
    }

    private func registerShortcuts(_ settings: Settings) {
        let wanted: [(mode: Mode, shortcut: Shortcut)] = [
            (.hint, settings.hintShortcut), (.search, settings.searchShortcut), (.scroll, settings.scrollShortcut),
        ]
        guard wanted.map(\.shortcut) != shortcuts.map(\.shortcut) else { return }

        hotkeys.unregisterAll()
        shortcuts = wanted
        for (mode, shortcut) in wanted {
            let registered = hotkeys.register(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers) { [weak self] in
                self?.toggle(mode)
            }
            if registered {
                log.notice("Registered \(shortcut.displayString, privacy: .public)")
            } else {
                log.error("Could not register \(shortcut.displayString, privacy: .public); another application may own it")
            }
        }
    }

    /// Starts or stops the optional activators to match the settings.
    func applySettings() {
        let settings = store.effective
        holdKey?.stop()
        holdKey = nil
        keySequence?.stop()
        keySequence = nil
        guard AXPermission.isGranted else { return }
        registerShortcuts(settings)

        let isSuppressed: @MainActor () -> Bool = { [weak self] in self?.active != nil }

        if settings.holdSpaceEnabled {
            let activator = HoldKeyActivator(delay: settings.holdDelay, isSuppressed: isSuppressed) { [weak self] in
                self?.toggle(.hint)
            }
            if activator.start() { holdKey = activator }
        }

        let bindings = [(settings.hintKeySequence, Mode.hint), (settings.scrollKeySequence, Mode.scroll)]
            .filter { !$0.0.isEmpty }
        if !bindings.isEmpty {
            let activator = KeySequenceActivator(
                sequences: bindings.map(\.0),
                resetDelay: settings.keySequenceResetDelay,
                isSuppressed: isSuppressed
            ) { [weak self] index in
                self?.toggle(bindings[index].1)
            }
            if activator.start() { keySequence = activator }
        }
    }

    /// Activates `mode`, or leaves it when it is already active. Another active mode is replaced.
    func toggle(_ mode: Mode) {
        if let active {
            active.stop()
            if active.mode == mode { return }
        }

        guard AXPermission.isGranted else { return refuse("the Accessibility permission is missing") }
        // Event taps receive nothing while a password field holds secure input.
        guard !SecureInput.isEnabled else { return refuse("secure input is active") }
        guard let application = currentTarget()?.application else {
            return refuse("the frontmost application is missing, ignored, or Vimac-AI itself")
        }

        let settings = store.effective
        let target: @MainActor () -> ModeTarget? = { [weak self] in self?.currentTarget() }
        let onShortcut: @MainActor (KeyStroke) -> Bool = { [weak self] stroke in
            self?.handleShortcut(stroke) ?? false
        }
        let onExit: @MainActor () -> Void = { [weak self] in
            self?.active = nil
        }

        let started: Bool
        let stop: @MainActor () -> Void
        switch mode {
        case .hint:
            applyStyle(settings)
            let controller = HintModeController(
                query: elementQuery(settings), overlay: overlay, interceptor: interceptor, settings: settings,
                memory: settings.stableLabels ? labelMemory : nil,
                target: target, onShortcut: onShortcut, onExit: onExit
            )
            started = controller.start()
            stop = { controller.stop() }
        case .search:
            applyStyle(settings)
            let controller = SearchModeController(
                query: elementQuery(settings), overlay: overlay, interceptor: interceptor, settings: settings,
                target: target, onShortcut: onShortcut, onExit: onExit
            )
            started = controller.start()
            stop = { controller.stop() }
        case .scroll:
            let controller = ScrollModeController(
                overlay: overlay, interceptor: interceptor, settings: settings,
                onShortcut: onShortcut, onExit: onExit
            )
            started = controller.start(application: application)
            stop = { controller.stop() }
        }

        guard started else { return refuse("the keyboard could not be intercepted") }
        active = (mode, stop)
    }

    private func applyStyle(_ settings: Settings) {
        overlay.style.fontSize = settings.hintFontSize
        overlay.style.cornerRadius = settings.hintCornerRadius
        overlay.style.theme = settings.hintTheme
    }

    private func elementQuery(_ settings: Settings) -> any ElementQuerying {
        VisionAugmentedQuery(base: AXElementQuery(), mode: settings.visionMode)
    }

    /// The frontmost application, unless it is this app or on the ignore list.
    private func currentTarget() -> ModeTarget? {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        guard let application = NSWorkspace.shared.frontmostApplication,
              application.processIdentifier != ownPID else { return nil }
        if let bundleID = application.bundleIdentifier, store.effective.ignoredBundleIDs.contains(bundleID) {
            return nil
        }
        let otherPIDs = NSWorkspace.shared.runningApplications
            .map(\.processIdentifier)
            .filter { $0 != ownPID && $0 != application.processIdentifier }
        return ModeTarget(application: application, otherPIDs: otherPIDs)
    }

    /// While a mode is active its event tap sees the shortcuts before the system does,
    /// so they are recognised here. Returns true when the key stroke was a shortcut.
    private func handleShortcut(_ stroke: KeyStroke) -> Bool {
        guard let match = shortcuts.first(where: { $0.shortcut.matches(stroke) }) else { return false }
        if !stroke.isRepeat {
            toggle(match.mode)
        }
        return true
    }

    private func refuse(_ reason: String) {
        log.notice("Not activating: \(reason, privacy: .public)")
        NSSound.beep()
    }
}
