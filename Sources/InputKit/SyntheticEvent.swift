// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics
import KeyfariCore

/// Marks the keyboard events this app posts, so its own event taps let them through.
enum SyntheticEvent {
    private static let marker: Int64 = 0x4B46_5249  // "KFRI"

    static func isOurs(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == marker
    }

    static func post(_ event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: marker)
        event.post(tap: .cghidEventTap)
    }
}

extension KeyStroke {
    /// Reads the key code, modifiers and repeat flag of a keyboard event.
    init(event: CGEvent) {
        let flags = event.flags
        var modifiers: Modifiers = []
        if flags.contains(.maskShift) { modifiers.insert(.shift) }
        if flags.contains(.maskControl) { modifiers.insert(.control) }
        if flags.contains(.maskAlternate) { modifiers.insert(.option) }
        if flags.contains(.maskCommand) { modifiers.insert(.command) }
        self.init(
            keyCode: UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode)),
            modifiers: modifiers,
            isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        )
    }
}
