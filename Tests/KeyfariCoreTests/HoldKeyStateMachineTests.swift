// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics
import Testing

@testable import KeyfariCore

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
