// SPDX-License-Identifier: GPL-3.0-only
/// A global keyboard shortcut: one key plus modifiers.
public struct Shortcut: Codable, Hashable, Sendable {
    public var keyCode: UInt16
    public var modifiers: Modifiers

    public init(keyCode: UInt16, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// A shortcut without Command, Control or Option would swallow ordinary typing.
    public var isUsable: Bool {
        !modifiers.isDisjoint(with: [.command, .control, .option])
    }

    public func matches(_ stroke: KeyStroke) -> Bool {
        stroke.keyCode == keyCode && stroke.modifiers == modifiers
    }

    /// The modifier symbols followed by the key name, one entry per key.
    public var displayParts: [String] {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        return parts + [KeyCode.name(of: keyCode)]
    }

    /// For example "⇧⌘Space".
    public var displayString: String {
        displayParts.joined()
    }
}

extension KeyCode {
    private static let names: [UInt16: String] = [
        KeyCode.return: "Return", KeyCode.tab: "Tab", KeyCode.space: "Space",
        KeyCode.delete: "Delete", KeyCode.escape: "Esc",
        KeyCode.leftArrow: "←", KeyCode.rightArrow: "→", KeyCode.downArrow: "↓", KeyCode.upArrow: "↑",
    ]

    /// A short human-readable name for a key.
    public static func name(of keyCode: UInt16) -> String {
        if let name = names[keyCode] { return name }
        if let character = characters[keyCode] { return character.uppercased() }
        return "Key \(keyCode)"
    }
}
