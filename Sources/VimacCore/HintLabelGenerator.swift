// Derived from AlphabetHints.swift in Vimac (https://github.com/nchudleigh/vimac),
// Copyright © 2019 Dexter Leng, licensed under GPL-3.0.

/// Generates the shortest set of hint labels in which no label is a prefix of another,
/// so a label can fire as soon as its last character is typed.
public enum HintLabelGenerator {
    public static let defaultAlphabet = "sadfjklewcmpgh"
    public static let minimumAlphabetSize = 6

    /// An alphabet is usable when it has enough distinct characters to keep labels short.
    public static func isValid(alphabet: String) -> Bool {
        alphabet.count >= minimumAlphabetSize && Set(alphabet).count == alphabet.count
    }

    /// Returns `count` uppercase labels built from `alphabet`.
    /// Returns an empty array when `count` is not positive or the alphabet has fewer than two distinct characters.
    public static func labels(count: Int, alphabet: String = defaultAlphabet) -> [String] {
        var seen = Set<Character>()
        let characters = alphabet.filter { seen.insert($0).inserted }
        guard count > 0, characters.count >= 2 else { return [] }

        // Breadth-first expansion: each round replaces the oldest label with one child per character.
        var labels = [""]
        var offset = 0
        while labels.count - offset < count || labels.count == 1 {
            let label = labels[offset]
            offset += 1
            for character in characters {
                labels.append(String(character) + label)
            }
        }

        return labels[offset..<(offset + count)]
            .sorted()
            .map { String($0.reversed()).uppercased() }
    }
}
