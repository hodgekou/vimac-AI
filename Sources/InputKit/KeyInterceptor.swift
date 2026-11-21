import CoreGraphics
import VimacCore

/// Swallows the keyboard while a mode is active and reports each key press.
@MainActor
public final class KeyInterceptor {
    private var tap: EventTap?
    private var onKeyDown: (@MainActor (KeyStroke) -> Void)?
    private var onKeyUp: (@MainActor (UInt16) -> Void)?
    /// Keys whose key-down was swallowed and whose key-up is still to come.
    private var heldKeys = Set<UInt16>()
    private var isDraining = false

    /// When set, only these key codes are swallowed and reported; every other key reaches the application.
    public var swallowOnly: Set<UInt16>?

    public init() {}

    /// Starts swallowing keys. Returns false when the event tap could not be installed.
    @discardableResult
    public func start(
        onKeyDown: @escaping @MainActor (KeyStroke) -> Void,
        onKeyUp: (@MainActor (UInt16) -> Void)? = nil
    ) -> Bool {
        self.onKeyDown = onKeyDown
        self.onKeyUp = onKeyUp
        isDraining = false
        swallowOnly = nil
        if tap == nil {
            tap = EventTap(types: [.keyDown, .keyUp]) { [weak self] type, event in
                self?.handle(type, event) ?? false
            }
        }
        return tap?.start() ?? false
    }

    /// Stops reporting keys. The tap stays until every swallowed key has been released,
    /// so the target application never sees a key-up without its key-down.
    public func stop() {
        onKeyDown = nil
        onKeyUp = nil
        swallowOnly = nil
        if heldKeys.isEmpty {
            tap?.stop()
        } else {
            isDraining = true
        }
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        let keyCode = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))

        if type == .keyUp {
            // A key that was already down before the mode started belongs to the application.
            guard heldKeys.remove(keyCode) != nil else { return false }
            onKeyUp?(keyCode)
            if isDraining, heldKeys.isEmpty {
                isDraining = false
                tap?.stop()
            }
            return true
        }

        guard type == .keyDown else { return false }
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

        if isDraining {
            // Only repeats of keys we already swallowed are still ours.
            return isRepeat && heldKeys.contains(keyCode)
        }

        if let swallowOnly, !swallowOnly.contains(keyCode) {
            return false
        }

        if isRepeat, !heldKeys.contains(keyCode) {
            // Repeats of a key held since before activation, typically the activation shortcut itself.
            return true
        }

        heldKeys.insert(keyCode)
        onKeyDown?(KeyStroke(keyCode: keyCode, modifiers: Self.modifiers(from: event.flags), isRepeat: isRepeat))
        return true
    }

    private static func modifiers(from flags: CGEventFlags) -> Modifiers {
        var modifiers: Modifiers = []
        if flags.contains(.maskShift) { modifiers.insert(.shift) }
        if flags.contains(.maskControl) { modifiers.insert(.control) }
        if flags.contains(.maskAlternate) { modifiers.insert(.option) }
        if flags.contains(.maskCommand) { modifiers.insert(.command) }
        return modifiers
    }
}
