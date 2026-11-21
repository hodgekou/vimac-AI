// SPDX-License-Identifier: GPL-3.0-only
/// Keeps the label of an element the same from one activation to the next.
public enum StableLabels {
    /// A key that identifies an element across activations, or nil when it has no text to tell it apart.
    public static func fingerprint(of element: ElementSnapshot) -> String? {
        let text = SearchSession.normalize(element.searchText)
        guard !text.isEmpty else { return nil }
        return "\(element.role)|\(text)"
    }

    /// Generates labels for `fingerprints.count` elements, giving each element its remembered
    /// label when that label exists in the generated set and is still free.
    ///
    /// The result is a permutation of `HintLabelGenerator.labels`, so it stays prefix-free.
    public static func assign(fingerprints: [String?], alphabet: String, memory: [String: String]) -> [String] {
        let generated = HintLabelGenerator.labels(count: fingerprints.count, alphabet: alphabet)
        var free = Set(generated)
        var result = [String?](repeating: nil, count: fingerprints.count)

        for (index, fingerprint) in fingerprints.enumerated() {
            guard let fingerprint, let remembered = memory[fingerprint], free.remove(remembered) != nil else { continue }
            result[index] = remembered
        }

        var remaining = generated.filter(free.contains).makeIterator()
        return result.map { $0 ?? remaining.next() ?? "" }
    }
}
