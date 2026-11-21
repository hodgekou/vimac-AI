import CoreGraphics
import Foundation

public enum SearchEvent: Equatable, Sendable {
    /// The query, the matches, the label prefix or the focus changed.
    case updated
    /// A label key that matches no label.
    case rejected
    /// Perform `action` on the candidate at `index`.
    case act(index: Int, action: ClickAction)
    case exit
    case ignored
}

/// The input state machine of search click mode.
///
/// Plain keys build a query that filters the candidates by their text. Each match gets a label;
/// typing a label with Shift held moves the focus, and Return acts on the focused match.
public struct SearchSession: Sendable {
    /// For each candidate, every form of its text that a query may match.
    private let texts: [[String]]
    private let alphabet: String

    public private(set) var query = ""
    /// Label characters typed so far with Shift held.
    public private(set) var labelPrefix = ""
    /// Indices of the candidates that match the query, in candidate order.
    public private(set) var matches: [Int] = []
    /// One label per match.
    public private(set) var labels: [String] = []
    /// Position of the focused match within `matches`.
    public private(set) var focus: Int?

    /// `texts` holds the searchable text of each candidate, in the order focus should move through them.
    public init(texts: [String], alphabet: String = HintLabelGenerator.defaultAlphabet) {
        self.texts = texts.map(Self.searchForms)
        self.alphabet = alphabet
    }

    /// The candidate that Return would act on.
    public var focusedIndex: Int? {
        focus.map { matches[$0] }
    }

    /// Search ignores case and whitespace.
    public static func normalize(_ text: String) -> String {
        text.lowercased().filter { !$0.isWhitespace }
    }

    /// The forms of `text` a query is compared against: the text itself and, when it contains
    /// non-Latin characters, its romanisation in full and as initials. Queries are typed by
    /// physical key, so Chinese text is found through its pinyin: "保存" matches "baocun" and "bc".
    public static func searchForms(_ text: String) -> [String] {
        let plain = normalize(text)
        guard !plain.isEmpty, !plain.allSatisfy(\.isASCII),
              let latin = text.applyingTransform(.toLatin, reverse: false)?
                  .applyingTransform(.stripDiacritics, reverse: false) else {
            return [plain]
        }
        // The transform yields one syllable per character, separated by spaces.
        let syllables = latin.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        let full = syllables.joined()
        let initials = String(syllables.compactMap(\.first))
        return [plain, full, initials].filter { !$0.isEmpty }
    }

    public mutating func handle(_ stroke: KeyStroke) -> SearchEvent {
        let shift = stroke.modifiers.contains(.shift)
        let control = stroke.modifiers.contains(.control)

        if stroke.keyCode == KeyCode.escape || (stroke.keyCode == KeyCode.leftBracket && control) {
            return .exit
        }

        switch stroke.keyCode {
        case KeyCode.return:
            guard !stroke.isRepeat, let index = focusedIndex else { return .ignored }
            return .act(index: index, action: Self.action(for: stroke.modifiers))
        case KeyCode.tab:
            return moveFocus(by: shift ? -1 : 1)
        case KeyCode.downArrow:
            return moveFocus(by: 1)
        case KeyCode.upArrow:
            return moveFocus(by: -1)
        case KeyCode.delete:
            if !labelPrefix.isEmpty {
                labelPrefix.removeLast()
                return .updated
            }
            guard !query.isEmpty else { return .ignored }
            query.removeLast()
            recompute()
            return .updated
        default:
            break
        }

        guard let character = stroke.character else { return .ignored }

        if control {
            switch character {
            case "n": return moveFocus(by: 1)
            case "p": return moveFocus(by: -1)
            default: return .ignored
            }
        }
        if stroke.isRepeat || stroke.modifiers.contains(.command) || stroke.modifiers.contains(.option) {
            return .ignored
        }

        if shift {
            if character.isLetter { return typeLabel(character) }
            // Shift-8 is the asterisk, which matches everything.
            guard character == "8" else { return .ignored }
            query.append("*")
        } else {
            query.append(character)
        }
        recompute()
        return .updated
    }

    private static func action(for modifiers: Modifiers) -> ClickAction {
        if modifiers.contains(.shift) { return .right }
        if modifiers.contains(.command) { return .commandLeft }
        if modifiers.contains(.option) { return .moveOnly }
        return .left
    }

    private mutating func moveFocus(by offset: Int) -> SearchEvent {
        guard let current = focus, !matches.isEmpty else { return .ignored }
        focus = ((current + offset) % matches.count + matches.count) % matches.count
        labelPrefix = ""
        return .updated
    }

    private mutating func typeLabel(_ character: Character) -> SearchEvent {
        let candidate = labelPrefix + character.uppercased()
        guard labels.contains(where: { $0.hasPrefix(candidate) }) else { return .rejected }
        if let position = labels.firstIndex(of: candidate) {
            focus = position
            labelPrefix = ""
        } else {
            labelPrefix = candidate
        }
        return .updated
    }

    private mutating func recompute() {
        let normalized = Self.normalize(query)
        if normalized.isEmpty {
            matches = []
        } else if normalized == "*" || normalized == ";" {
            matches = Array(texts.indices)
        } else {
            matches = texts.indices.filter { index in texts[index].contains { $0.contains(normalized) } }
        }
        labels = HintLabelGenerator.labels(count: matches.count, alphabet: alphabet)
        focus = matches.isEmpty ? nil : 0
        labelPrefix = ""
    }
}

public enum ReadingOrder {
    /// Sorts elements top to bottom, and left to right within a row.
    public static func sorted(_ elements: [ElementSnapshot]) -> [ElementSnapshot] {
        // Elements whose click points fall in the same 12-point band count as one row.
        func key(_ element: ElementSnapshot) -> (Int, CGFloat) {
            (Int((element.clickPoint.y / 12).rounded(.down)), element.clickPoint.x)
        }
        return elements.sorted { key($0) < key($1) }
    }
}

extension ElementSnapshot {
    /// Roles that take typed text. A click chain stops on them so that typing reaches the field.
    public var acceptsText: Bool {
        ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"].contains(role)
    }
}
