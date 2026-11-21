// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics
import Testing

@testable import KeyfariCore

@Suite struct KeySequenceMatcherTests {
    @Test func completesASequence() {
        var matcher = KeySequenceMatcher(sequences: ["fd", "jk"])
        #expect(matcher.keyDown("f") == .hold)
        #expect(matcher.keyDown("d") == .matched(0))
        #expect(!matcher.isPending)
        #expect(matcher.keyDown("j") == .hold)
        #expect(matcher.keyDown("k") == .matched(1))
    }

    @Test func unrelatedKeysPass() {
        var matcher = KeySequenceMatcher(sequences: ["fd"])
        #expect(matcher.keyDown("x") == .pass)
        #expect(matcher.keyDown(nil) == .pass)
    }

    @Test func brokenSequenceReleasesTheWithheldKeys() {
        var matcher = KeySequenceMatcher(sequences: ["fd"])
        _ = matcher.keyDown("f")
        #expect(matcher.keyDown("x") == .release(holdCurrent: false))
        #expect(!matcher.isPending)
    }

    @Test func breakingKeyCanStartANewSequence() {
        var matcher = KeySequenceMatcher(sequences: ["fd"])
        _ = matcher.keyDown("f")
        #expect(matcher.keyDown("f") == .release(holdCurrent: true))
        #expect(matcher.keyDown("d") == .matched(0))
    }

    @Test func modifiedKeyAndTimeoutRelease() {
        var matcher = KeySequenceMatcher(sequences: ["fd"])
        _ = matcher.keyDown("f")
        #expect(matcher.keyDown(nil) == .release(holdCurrent: false))
        let nothingToRelease = matcher.timeout()
        #expect(nothingToRelease == false)
        _ = matcher.keyDown("f")
        let released = matcher.timeout()
        #expect(released == true)
        #expect(!matcher.isPending)
    }

    @Test func rejectsShortAndConflictingSequences() {
        #expect(KeySequenceMatcher.usable(["FD", "jk"]) == ["fd", "jk"])
        #expect(KeySequenceMatcher.usable(["f", ""]) == [nil, nil])
        // One is a prefix of the other, so neither can be told apart in time.
        #expect(KeySequenceMatcher.usable(["fd", "fdd"]) == [nil, nil])
        #expect(KeySequenceMatcher.usable(["fd", "fd"]) == [nil, nil])
        #expect(KeySequenceMatcher.usable(["f d", "jk"]) == [nil, "jk"])
    }
}
