import CoreGraphics
import Testing
@testable import VimacCore

@Suite struct HoldKeyStateMachineTests {
    let space = KeyStroke(keyCode: KeyCode.space)
    let a = KeyStroke(keyCode: 0)

    @Test func holdingPastTheDelayActivates() {
        var machine = HoldKeyStateMachine()
        #expect(machine.keyDown(space, suppressed: false) == .swallowAndStartTimer)
        #expect(machine.keyDown(KeyStroke(keyCode: KeyCode.space, isRepeat: true), suppressed: false) == .swallow)
        #expect(machine.timerFired() == .activate)
        // The physical key is still down: its repeats and its release must not reach the application.
        #expect(machine.keyDown(KeyStroke(keyCode: KeyCode.space, isRepeat: true), suppressed: true) == .swallow)
        #expect(machine.keyUp(keyCode: KeyCode.space) == .swallow)
        #expect(machine.state == .idle)
    }

    @Test func quickTapIsReplayed() {
        var machine = HoldKeyStateMachine()
        _ = machine.keyDown(space, suppressed: false)
        #expect(machine.keyUp(keyCode: KeyCode.space) == .replayTap)
        #expect(machine.state == .idle)
        #expect(machine.timerFired() == .pass)
    }

    @Test func anotherKeyDuringTheDelayKeepsTypingOrder() {
        var machine = HoldKeyStateMachine()
        _ = machine.keyDown(space, suppressed: false)
        #expect(machine.keyDown(a, suppressed: false) == .replayThenResend)
        // The real release of the hold key now passes through like any other.
        #expect(machine.keyUp(keyCode: KeyCode.space) == .pass)
    }

    @Test func modifiersRepeatsAndActiveModesAreLeftAlone() {
        var machine = HoldKeyStateMachine()
        #expect(machine.keyDown(KeyStroke(keyCode: KeyCode.space, modifiers: .command), suppressed: false) == .pass)
        #expect(machine.keyDown(KeyStroke(keyCode: KeyCode.space, isRepeat: true), suppressed: false) == .pass)
        #expect(machine.keyDown(space, suppressed: true) == .pass)
        #expect(machine.keyDown(a, suppressed: false) == .pass)
        #expect(machine.keyUp(keyCode: 0) == .pass)
    }
}

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

@Suite struct VisionMergeTests {
    @Test func intersectionOverUnion() {
        let a = CGRect(x: 0, y: 0, width: 10, height: 10)
        #expect(VisionMerge.intersectionOverUnion(a, a) == 1)
        #expect(VisionMerge.intersectionOverUnion(a, CGRect(x: 20, y: 20, width: 5, height: 5)) == 0)
        let half = VisionMerge.intersectionOverUnion(a, CGRect(x: 5, y: 0, width: 10, height: 10))
        #expect(abs(half - 1.0 / 3.0) < 0.0001)
    }

    @Test func keepsOnlyRegionsThatAddSomething() {
        let existing = [CGRect(x: 0, y: 0, width: 100, height: 30)]
        let regions = [
            CGRect(x: 20, y: 8, width: 60, height: 14),    // the title of the existing button
            CGRect(x: 0, y: 100, width: 80, height: 16),   // text nothing covers
            CGRect(x: 300, y: 300, width: 4, height: 4),   // noise
        ]
        #expect(VisionMerge.newRegions(regions, existing: existing) == [1])
    }
}
