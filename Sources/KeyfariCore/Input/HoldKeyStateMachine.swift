// SPDX-License-Identifier: GPL-3.0-only
// Derived from HoldKeyListener.swift in Vimac (https://github.com/nchudleigh/vimac),
// Copyright © 2021 Dexter Leng, licensed under GPL-3.0.

/// Decides whether a press of the hold key is a normal key press or a request to activate a mode.
///
/// The key-down is withheld until it is clear which one it is: released early or followed by
/// another key, it is replayed and typing is unaffected; held past the delay, it activates.
public struct HoldKeyStateMachine: Sendable {
    public enum State: Equatable, Sendable {
        case idle
        /// The key is down and withheld, waiting for the delay.
        case pending
        /// The mode was activated and the key is still physically down.
        case held
    }

    public enum Output: Equatable, Sendable {
        /// Let the event through untouched.
        case pass
        /// Drop the event.
        case swallow
        /// Drop the event and start the delay timer.
        case swallowAndStartTimer
        /// Drop the event, cancel the timer, and post the withheld key-down followed by a key-up.
        case replayTap
        /// Drop the event, cancel the timer, and post the withheld key-down followed by this event.
        case replayThenResend
        /// The key was held long enough.
        case activate
    }

    public let keyCode: UInt16
    public private(set) var state = State.idle

    public init(keyCode: UInt16 = KeyCode.space) {
        self.keyCode = keyCode
    }

    /// - Parameter suppressed: true while a mode is active, when the key has its own meaning.
    public mutating func keyDown(_ stroke: KeyStroke, suppressed: Bool) -> Output {
        switch state {
        case .idle:
            guard !suppressed, stroke.keyCode == keyCode, stroke.modifiers.isEmpty, !stroke.isRepeat else {
                return .pass
            }
            state = .pending
            return .swallowAndStartTimer
        case .pending:
            if stroke.keyCode == keyCode { return .swallow }
            // Another key arrived first, so this was typing.
            state = .idle
            return .replayThenResend
        case .held:
            return stroke.keyCode == keyCode ? .swallow : .pass
        }
    }

    public mutating func keyUp(keyCode released: UInt16) -> Output {
        guard released == keyCode else { return .pass }
        switch state {
        case .idle:
            return .pass
        case .pending:
            state = .idle
            return .replayTap
        case .held:
            state = .idle
            return .swallow
        }
    }

    public mutating func timerFired() -> Output {
        guard state == .pending else { return .pass }
        state = .held
        return .activate
    }

    /// Forgets a withheld key, for example when the listener is switched off.
    public mutating func reset() {
        state = .idle
    }
}
