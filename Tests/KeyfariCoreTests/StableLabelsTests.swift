// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics
import Testing

@testable import KeyfariCore

@Suite struct StableLabelsTests {
    func button(_ text: String) -> ElementSnapshot {
        ElementSnapshot(role: "AXButton", frame: .zero, searchText: text)
    }

    @Test func fingerprintNeedsText() {
        #expect(StableLabels.fingerprint(of: button("Save File")) == "AXButton|savefile")
        #expect(StableLabels.fingerprint(of: button("  ")) == nil)
    }

    @Test func rememberedLabelIsReused() {
        let fingerprints: [String?] = ["a", "b", "c"]
        let plain = StableLabels.assign(fingerprints: fingerprints, alphabet: "sdf", memory: [:])
        // The generator hands labels out in sorted order.
        #expect(plain == ["D", "F", "S"])

        let remembered = StableLabels.assign(fingerprints: fingerprints, alphabet: "sdf", memory: ["a": "S"])
        #expect(remembered[0] == "S")
        #expect(Set(remembered) == ["S", "D", "F"])
    }

    @Test func labelOutsideTheGeneratedSetIsIgnored() {
        let labels = StableLabels.assign(fingerprints: ["a", nil], alphabet: "sdf", memory: ["a": "ZZ"])
        #expect(labels == ["D", "S"])
    }

    @Test func twoElementsCannotShareARememberedLabel() {
        let labels = StableLabels.assign(fingerprints: ["a", "a", "b"], alphabet: "sdf", memory: ["a": "F"])
        #expect(labels[0] == "F")
        #expect(Set(labels).count == 3)
    }
}
