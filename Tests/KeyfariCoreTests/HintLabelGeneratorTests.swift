// SPDX-License-Identifier: GPL-3.0-only

import Testing

@testable import KeyfariCore

@Suite struct HintLabelGeneratorTests {
    @Test func returnsNothingForNonPositiveCount() {
        #expect(HintLabelGenerator.labels(count: 0).isEmpty)
        #expect(HintLabelGenerator.labels(count: -3).isEmpty)
    }

    @Test func returnsNothingWhenAlphabetCannotBranch() {
        #expect(HintLabelGenerator.labels(count: 5, alphabet: "").isEmpty)
        #expect(HintLabelGenerator.labels(count: 5, alphabet: "aaa").isEmpty)
    }

    @Test func usesSingleCharactersWhileTheyLast() {
        #expect(HintLabelGenerator.labels(count: 3, alphabet: "abc") == ["A", "B", "C"])
    }

    @Test func growsOnlyAsManyLabelsAsNeeded() {
        #expect(HintLabelGenerator.labels(count: 3, alphabet: "ab") == ["AA", "B", "AB"])
    }

    @Test(arguments: [1, 2, 13, 14, 15, 100, 500, 2000])
    func labelsAreUniqueAndPrefixFree(count: Int) {
        let labels = HintLabelGenerator.labels(count: count)
        #expect(labels.count == count)
        #expect(Set(labels).count == count)

        let sorted = labels.sorted()
        for (previous, next) in zip(sorted, sorted.dropFirst()) {
            #expect(!next.hasPrefix(previous), "\(previous) is a prefix of \(next)")
        }
    }

    @Test func validatesAlphabets() {
        #expect(HintLabelGenerator.isValid(alphabet: HintLabelGenerator.defaultAlphabet))
        #expect(!HintLabelGenerator.isValid(alphabet: "abcde"))
        #expect(!HintLabelGenerator.isValid(alphabet: "aabcdef"))
    }
}
