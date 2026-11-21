import CoreGraphics
import Foundation
import VimacCore

/// Activates a mode when Space is held, without disturbing normal typing.
@MainActor
public final class HoldKeyActivator {
    private let delay: TimeInterval
    private let isSuppressed: @MainActor () -> Bool
    private let onActivate: @MainActor () -> Void

    private var machine = HoldKeyStateMachine()
    private var tap: EventTap?
    private var withheld: CGEvent?
    private var timer: Timer?

    /// - Parameters:
    ///   - delay: how long Space must stay down, in seconds.
    ///   - isSuppressed: true while a mode is active, when Space has its own meaning.
    public init(
        delay: TimeInterval,
        isSuppressed: @escaping @MainActor () -> Bool,
        onActivate: @escaping @MainActor () -> Void
    ) {
        self.delay = delay
        self.isSuppressed = isSuppressed
        self.onActivate = onActivate
    }

    @discardableResult
    public func start() -> Bool {
        if tap == nil {
            tap = EventTap(types: [.keyDown, .keyUp]) { [weak self] type, event in
                self?.handle(type, event) ?? false
            }
        }
        return tap?.start() ?? false
    }

    public func stop() {
        cancelTimer()
        // A withheld key-down must not be lost when the listener goes away.
        if let withheld {
            SyntheticEvent.post(withheld)
            self.withheld = nil
        }
        machine.reset()
        tap?.stop()
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        guard !SyntheticEvent.isOurs(event) else { return false }
        let stroke = KeyStroke(event: event)

        let output = type == .keyDown
            ? machine.keyDown(stroke, suppressed: isSuppressed())
            : machine.keyUp(keyCode: stroke.keyCode)

        switch output {
        case .pass, .activate:
            return false
        case .swallow:
            return true
        case .swallowAndStartTimer:
            withheld = event.copy()
            timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.timerFired() }
            }
            return true
        case .replayTap:
            cancelTimer()
            if let down = withheld, let up = down.copy() {
                up.type = .keyUp
                SyntheticEvent.post(down)
                SyntheticEvent.post(up)
            }
            withheld = nil
            return true
        case .replayThenResend:
            cancelTimer()
            // Both are posted, rather than letting this event through, so they arrive in typing order.
            if let down = withheld { SyntheticEvent.post(down) }
            if let current = event.copy() { SyntheticEvent.post(current) }
            withheld = nil
            return true
        }
    }

    private func timerFired() {
        timer = nil
        guard machine.timerFired() == .activate else { return }
        withheld = nil
        onActivate()
    }

    private func cancelTimer() {
        timer?.invalidate()
        timer = nil
    }
}
