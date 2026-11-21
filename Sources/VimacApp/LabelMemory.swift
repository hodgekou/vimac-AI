import Foundation
import VimacCore

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
    func assign(to elements: [ElementSnapshot], bundleID: String, alphabet: String) -> [String] {
        StableLabels.assign(
            fingerprints: elements.map { key(for: $0, bundleID: bundleID) },
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
