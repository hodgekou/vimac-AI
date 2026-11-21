// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import Testing

@testable import KeyfariCore

@Suite struct HintSessionAppendTests {
    @Test func appendedLabelsCanBeTyped() {
        var session = HintSession(labels: ["A", "S"])
        session.append(labels: ["DA", "DS"])
        #expect(session.labels == ["A", "S", "DA", "DS"])
        // d
        #expect(session.handle(KeyStroke(keyCode: 2)) == .updated(prefix: "D", visible: [2, 3]))
        // s
        #expect(session.handle(KeyStroke(keyCode: 1)) == .matched(index: 3, action: .left))
    }

    @Test func reservedLabelsStayPrefixFree() {
        // Labels for the visible elements and for a reserve are generated together,
        // so the ones handed out later cannot clash with the ones already shown.
        let all = HintLabelGenerator.labels(count: 30, alphabet: "sadfjkl")
        let shown = Array(all.prefix(12)), later = Array(all.dropFirst(12))
        for label in later {
            #expect(!shown.contains { label.hasPrefix($0) || $0.hasPrefix(label) })
        }
    }
}
