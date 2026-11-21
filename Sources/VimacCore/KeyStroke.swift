/// Modifier keys held during a key stroke.
public struct Modifiers: OptionSet, Hashable, Sendable, Codable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let shift = Modifiers(rawValue: 1 << 0)
    public static let control = Modifiers(rawValue: 1 << 1)
    public static let option = Modifiers(rawValue: 1 << 2)
    public static let command = Modifiers(rawValue: 1 << 3)
}

/// A key press identified by its physical key code, independent of the active input method.
public struct KeyStroke: Hashable, Sendable {
    public let keyCode: UInt16
    public let modifiers: Modifiers
    public let isRepeat: Bool

    public init(keyCode: UInt16, modifiers: Modifiers = [], isRepeat: Bool = false) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.isRepeat = isRepeat
    }

    /// The unshifted character printed on this key of an ANSI keyboard, if it has one.
    public var character: Character? {
        KeyCode.characters[keyCode]
    }
}

/// Virtual key codes of an ANSI keyboard.
public enum KeyCode {
    public static let `return`: UInt16 = 36
    public static let tab: UInt16 = 48
    public static let space: UInt16 = 49
    public static let delete: UInt16 = 51
    public static let escape: UInt16 = 53
    public static let leftArrow: UInt16 = 123
    public static let rightArrow: UInt16 = 124
    public static let downArrow: UInt16 = 125
    public static let upArrow: UInt16 = 126
    public static let leftBracket: UInt16 = 33
    public static let j: UInt16 = 38
    public static let slash: UInt16 = 44

    static let characters: [UInt16: Character] = [
        0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x", 8: "c", 9: "v",
        11: "b", 12: "q", 13: "w", 14: "e", 15: "r", 16: "y", 17: "t",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7",
        27: "-", 28: "8", 29: "0", 30: "]", 31: "o", 32: "u", 33: "[", 34: "i", 35: "p",
        37: "l", 38: "j", 39: "'", 40: "k", 41: ";", 42: "\\", 43: ",", 44: "/",
        45: "n", 46: "m", 47: ".", 50: "`",
    ]
}

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

    /// For example "⌘⇧Space".
    public var displayString: String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        return result + KeyCode.name(of: keyCode)
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
