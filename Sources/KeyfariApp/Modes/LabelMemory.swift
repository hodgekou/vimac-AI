// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KeyfariCore

/// Remembers which label each clicked element had, per application.
@MainActor
final class LabelMemory {
    private static let key = "labelMemory"
    private static let capacity = 3000

    private let defaults: UserDefaults
    private var labels: [String: String]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        labels = defaults.dictionary(forKey: Self.key) as? [String: String] ?? [:]
    }

    /// Labels for `elements`, reusing remembered ones where possible.
    /// `reserve` extra labels follow, for elements that are not known yet.
    func assign(to elements: [ElementSnapshot], bundleID: String, alphabet: String, reserve: Int = 0) -> [String] {
        StableLabels.assign(
            fingerprints: elements.map { key(for: $0, bundleID: bundleID) } + [String?](repeating: nil, count: reserve),
            alphabet: alphabet,
            memory: labels
        )
    }

    func remember(_ label: String, for element: ElementSnapshot, bundleID: String) {
        guard let key = key(for: element, bundleID: bundleID), labels[key] != label else { return }
        // Simple bound: starting over is cheaper than tracking which entries are oldest.
        if labels.count >= Self.capacity { labels.removeAll() }
        labels[key] = label
        defaults.set(labels, forKey: Self.key)
    }

    private func key(for element: ElementSnapshot, bundleID: String) -> String? {
        StableLabels.fingerprint(of: element).map { "\(bundleID)|\($0)" }
    }
}
