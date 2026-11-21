import CoreGraphics

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

/// Combines text found on screen with the elements the accessibility tree already provides.
public enum VisionMerge {
    public static func intersectionOverUnion(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let intersection = a.intersection(b)
        guard !intersection.isNull, !intersection.isEmpty else { return 0 }
        let overlap = intersection.width * intersection.height
        let union = a.width * a.height + b.width * b.height - overlap
        return union > 0 ? overlap / union : 0
    }

    /// Returns the regions worth a label of their own.
    ///
    /// A region is dropped when it is tiny, when it overlaps an existing element heavily, or when
    /// its centre lies inside one: that is the title of a button which already has a label.
    public static func newRegions(
        _ regions: [CGRect],
        existing: [CGRect],
        minimumSide: CGFloat = 8,
        overlapThreshold: CGFloat = 0.5
    ) -> [Int] {
        regions.indices.filter { index in
            let region = regions[index]
            guard region.width >= minimumSide, region.height >= minimumSide else { return false }
            let center = CGPoint(x: region.midX, y: region.midY)
            return !existing.contains { frame in
                frame.contains(center) || intersectionOverUnion(frame, region) > overlapThreshold
            }
        }
    }
}
