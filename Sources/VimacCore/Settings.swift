/// When on-screen text recognition adds labels.
public enum VisionMode: String, Codable, Sendable, CaseIterable {
    case off
    /// Only when the accessibility tree of the window is nearly empty.
    case fallback
    case always
}

public enum HintTheme: String, Codable, Sendable, CaseIterable {
    case yellow
    case dark
    case light
}

/// User preferences. Stored as one JSON document.
public struct Settings: Codable, Equatable, Sendable {
    public var hintAlphabet = HintLabelGenerator.defaultAlphabet
    public var hintFontSize = 11.0
    public var hintTheme = HintTheme.yellow
    public var hintCornerRadius = 3.0
    public var hintShortcut = Shortcut(keyCode: KeyCode.space, modifiers: [.command, .shift])
    public var searchShortcut = Shortcut(keyCode: KeyCode.slash, modifiers: [.command, .shift])
    public var scrollShortcut = Shortcut(keyCode: KeyCode.j, modifiers: [.command, .shift])
    /// Keep the mode open after a click so several elements can be clicked in a row.
    public var chainClicks = false
    /// Give an element the label it had the last time it was clicked.
    public var stableLabels = true
    public var holdSpaceEnabled = false
    /// How long Space must be held, in seconds.
    public var holdDelay = 0.25
    /// Typed sequences that activate a mode. Empty means off.
    public var hintKeySequence = ""
    public var scrollKeySequence = ""
    /// How long the next key of a sequence may take, in seconds.
    public var keySequenceResetDelay = 0.25
    public var visionMode = VisionMode.off
    /// Pixels scrolled per frame while a scroll key is held.
    public var scrollSpeed = 20
    /// Speed factor applied while Shift is held.
    public var dashMultiplier = 3.0
    public var reverseHorizontal = false
    public var reverseVertical = false
    /// Bundle identifiers of applications in which no mode activates.
    public var ignoredBundleIDs: [String] = []
    public var launchAtLogin = false

    public init() {}

    // Decodes field by field so that a document written by an older version keeps its values.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Settings()
        hintAlphabet = try container.decodeIfPresent(String.self, forKey: .hintAlphabet) ?? fallback.hintAlphabet
        hintFontSize = try container.decodeIfPresent(Double.self, forKey: .hintFontSize) ?? fallback.hintFontSize
        hintTheme = (try? container.decodeIfPresent(HintTheme.self, forKey: .hintTheme)) ?? fallback.hintTheme
        hintCornerRadius = try container.decodeIfPresent(Double.self, forKey: .hintCornerRadius) ?? fallback.hintCornerRadius
        hintShortcut = (try? container.decodeIfPresent(Shortcut.self, forKey: .hintShortcut)) ?? fallback.hintShortcut
        searchShortcut = (try? container.decodeIfPresent(Shortcut.self, forKey: .searchShortcut)) ?? fallback.searchShortcut
        scrollShortcut = (try? container.decodeIfPresent(Shortcut.self, forKey: .scrollShortcut)) ?? fallback.scrollShortcut
        chainClicks = try container.decodeIfPresent(Bool.self, forKey: .chainClicks) ?? fallback.chainClicks
        stableLabels = try container.decodeIfPresent(Bool.self, forKey: .stableLabels) ?? fallback.stableLabels
        holdSpaceEnabled = try container.decodeIfPresent(Bool.self, forKey: .holdSpaceEnabled) ?? fallback.holdSpaceEnabled
        holdDelay = try container.decodeIfPresent(Double.self, forKey: .holdDelay) ?? fallback.holdDelay
        hintKeySequence = try container.decodeIfPresent(String.self, forKey: .hintKeySequence) ?? fallback.hintKeySequence
        scrollKeySequence = try container.decodeIfPresent(String.self, forKey: .scrollKeySequence) ?? fallback.scrollKeySequence
        keySequenceResetDelay = try container.decodeIfPresent(Double.self, forKey: .keySequenceResetDelay) ?? fallback.keySequenceResetDelay
        visionMode = (try? container.decodeIfPresent(VisionMode.self, forKey: .visionMode)) ?? fallback.visionMode
        scrollSpeed = try container.decodeIfPresent(Int.self, forKey: .scrollSpeed) ?? fallback.scrollSpeed
        dashMultiplier = try container.decodeIfPresent(Double.self, forKey: .dashMultiplier) ?? fallback.dashMultiplier
        reverseHorizontal = try container.decodeIfPresent(Bool.self, forKey: .reverseHorizontal) ?? fallback.reverseHorizontal
        reverseVertical = try container.decodeIfPresent(Bool.self, forKey: .reverseVertical) ?? fallback.reverseVertical
        ignoredBundleIDs = try container.decodeIfPresent([String].self, forKey: .ignoredBundleIDs) ?? fallback.ignoredBundleIDs
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? fallback.launchAtLogin
    }

    /// A copy in which every out-of-range value is replaced by its default.
    public func validated() -> Settings {
        let fallback = Settings()
        var result = self

        let alphabet = hintAlphabet.lowercased()
        result.hintAlphabet = HintLabelGenerator.isValid(alphabet: alphabet) && alphabet.allSatisfy(\.isLetter)
            ? alphabet
            : fallback.hintAlphabet
        if !(8...32).contains(hintFontSize) { result.hintFontSize = fallback.hintFontSize }
        if !(0...10).contains(hintCornerRadius) { result.hintCornerRadius = fallback.hintCornerRadius }

        // Shortcuts must be distinct and carry a real modifier; otherwise all three return to their defaults.
        let shortcuts = [hintShortcut, searchShortcut, scrollShortcut]
        if Set(shortcuts).count != shortcuts.count || !shortcuts.allSatisfy(\.isUsable) {
            result.hintShortcut = fallback.hintShortcut
            result.searchShortcut = fallback.searchShortcut
            result.scrollShortcut = fallback.scrollShortcut
        }
        if !(1...100).contains(scrollSpeed) { result.scrollSpeed = fallback.scrollSpeed }
        if !(0.25...10).contains(dashMultiplier) { result.dashMultiplier = fallback.dashMultiplier }
        if !(0.1...1).contains(holdDelay) { result.holdDelay = fallback.holdDelay }
        if !(0.1...1).contains(keySequenceResetDelay) { result.keySequenceResetDelay = fallback.keySequenceResetDelay }

        // A sequence that is too short or collides with the other one is switched off.
        let sequences = KeySequenceMatcher.usable([hintKeySequence, scrollKeySequence])
        result.hintKeySequence = sequences[0] ?? ""
        result.scrollKeySequence = sequences[1] ?? ""

        var seen = Set<String>()
        result.ignoredBundleIDs = ignoredBundleIDs
            .map { $0.filter { !$0.isWhitespace } }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
        return result
    }
}
