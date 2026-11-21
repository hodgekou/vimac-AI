import CoreGraphics
import Foundation
import VimacCore

/// Activates a mode when a short sequence such as "fd" is typed.
@MainActor
public final class KeySequenceActivator {
    private let resetDelay: TimeInterval
    private let isSuppressed: @MainActor () -> Bool
    private let onMatch: @MainActor (Int) -> Void

    private var matcher: KeySequenceMatcher
    private var tap: EventTap?
    private var timer: Timer?
    /// Withheld events in arrival order, key-ups included.
    private var withheld: [CGEvent] = []
    /// Keys whose key-down is withheld and whose key-up has not arrived.
    private var withheldDown = Set<UInt16>()
    /// Keys of a completed sequence whose key-up must still be dropped.
    private var discardUp = Set<UInt16>()

    /// - Parameters:
    ///   - sequences: from `KeySequenceMatcher.usable`; `onMatch` receives the index into this array.
    ///   - resetDelay: how long the next key of a sequence may take, in seconds.
    public init(
        sequences: [String],
        resetDelay: TimeInterval,
        isSuppressed: @escaping @MainActor () -> Bool,
        onMatch: @escaping @MainActor (Int) -> Void
    ) {
        matcher = KeySequenceMatcher(sequences: sequences)
        self.resetDelay = resetDelay
        self.isSuppressed = isSuppressed
        self.onMatch = onMatch
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
        if matcher.timeout() { release() }
        discardUp.removeAll()
        tap?.stop()
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        guard !SyntheticEvent.isOurs(event) else { return false }
        let stroke = KeyStroke(event: event)
        let keyCode = stroke.keyCode

        if type == .keyUp {
            if discardUp.remove(keyCode) != nil { return true }
            guard withheldDown.remove(keyCode) != nil else { return false }
            // The key-up waits with its key-down so the pair is replayed or dropped together.
            if let copy = event.copy() { withheld.append(copy) }
            return true
        }

        if isSuppressed() {
            if matcher.timeout() {
                cancelTimer()
                release()
            }
            return false
        }
        if stroke.isRepeat {
            return withheldDown.contains(keyCode) || discardUp.contains(keyCode)
        }

        let character = stroke.modifiers.isEmpty ? stroke.character : nil
        switch matcher.keyDown(character) {
        case .pass:
            return false
        case .hold:
            hold(event, keyCode)
            return true
        case let .matched(index):
            cancelTimer()
            discardUp.formUnion(withheldDown)
            discardUp.insert(keyCode)
            withheld.removeAll()
            withheldDown.removeAll()
            onMatch(index)
            return true
        case let .release(holdCurrent):
            cancelTimer()
            release()
            if holdCurrent {
                hold(event, keyCode)
            } else if let copy = event.copy() {
                // Posted, rather than let through, so it arrives after the released keys.
                SyntheticEvent.post(copy)
            }
            return true
        }
    }

    private func hold(_ event: CGEvent, _ keyCode: UInt16) {
        if let copy = event.copy() { withheld.append(copy) }
        withheldDown.insert(keyCode)
        cancelTimer()
        timer = Timer.scheduledTimer(withTimeInterval: resetDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.timer = nil
                if self.matcher.timeout() { self.release() }
            }
        }
    }

    /// Posts the withheld events. Key-ups still to come then pass through on their own.
    private func release() {
        withheld.forEach(SyntheticEvent.post)
        withheld.removeAll()
        withheldDown.removeAll()
    }

    private func cancelTimer() {
        timer?.invalidate()
        timer = nil
    }
}
