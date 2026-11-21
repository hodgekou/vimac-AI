// SPDX-License-Identifier: GPL-3.0-only
/// Recognises short typed sequences such as "fd" that activate a mode.
///
/// Keys that could start a sequence are withheld. When the sequence completes they are discarded;
/// when it breaks or times out they are released, so normal typing only sees a short delay.
public struct KeySequenceMatcher: Sendable {
    public enum Output: Equatable, Sendable {
        /// Let the key through untouched.
        case pass
        /// Withhold the key and wait for the next one.
        case hold
        /// The sequence at this index completed. Discard every withheld key and this one.
        case matched(Int)
        /// Post the withheld keys. Then withhold this key when `holdCurrent` is true, otherwise post it too.
        case release(holdCurrent: Bool)
    }

    public let sequences: [String]
    private var buffer = ""

    /// `sequences` should come from `usable(_:)`.
    public init(sequences: [String]) {
        self.sequences = sequences
    }

    public var isPending: Bool { !buffer.isEmpty }

    /// Keeps the sequences that can work: at least two characters, all typeable, and none
    /// equal to or a prefix of another. Unusable entries become nil so indices stay aligned.
    public static func usable(_ candidates: [String]) -> [String?] {
        let typeable = Set(KeyCode.characters.values)
        let cleaned = candidates.map { $0.lowercased() }
        return cleaned.enumerated().map { index, sequence in
            guard sequence.count >= 2, sequence.allSatisfy(typeable.contains) else { return nil }
            let conflicts = cleaned.enumerated().contains { other, candidate in
                other != index && !candidate.isEmpty
                    && (candidate.hasPrefix(sequence) || sequence.hasPrefix(candidate))
            }
            return conflicts ? nil : sequence
        }
    }

    /// - Parameter character: the unshifted character of the key, or nil for keys without one
    ///   and for any key pressed with a modifier.
    public mutating func keyDown(_ character: Character?) -> Output {
        guard let character else { return flush() }

        let candidate = buffer + String(character)
        if let index = sequences.firstIndex(of: candidate) {
            buffer = ""
            return .matched(index)
        }
        if sequences.contains(where: { $0.hasPrefix(candidate) }) {
            buffer = candidate
            return .hold
        }
        guard isPending else { return .pass }

        // The sequence broke. This key may still start a new one.
        let restart = String(character)
        if sequences.contains(where: { $0.hasPrefix(restart) }) {
            buffer = restart
            return .release(holdCurrent: true)
        }
        buffer = ""
        return .release(holdCurrent: false)
    }

    /// Call when no key followed in time. Returns true when withheld keys must be released.
    public mutating func timeout() -> Bool {
        guard isPending else { return false }
        buffer = ""
        return true
    }

    private mutating func flush() -> Output {
        guard isPending else { return .pass }
        buffer = ""
        return .release(holdCurrent: false)
    }
}
