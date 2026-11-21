// SPDX-License-Identifier: GPL-3.0-only

public enum ScrollDirection: Equatable, Sendable {
    case left, down, up, right
}

public enum ScrollEvent: Equatable, Sendable {
    /// Scroll continuously until `stop`. `dash` asks for the faster speed.
    case start(ScrollDirection, dash: Bool)
    case stop
    /// Scroll by half the height of the scroll area.
    case halfPage(ScrollDirection)
    case top
    case bottom
    case selectArea(Int)
    case exit
    case ignored
}

/// The input state machine of scroll mode.
public struct ScrollSession: Sendable {
    /// How long the second `g` of `gg` may take, in seconds.
    public static let sequenceTimeout = 0.5

    public let areaCount: Int
    public private(set) var areaIndex = 0
    private var firstGTime: Double?
    private var scrollingKey: UInt16?

    public init(areaCount: Int) {
        self.areaCount = max(areaCount, 1)
    }

    /// `time` is a monotonic timestamp in seconds.
    public mutating func keyDown(_ stroke: KeyStroke, at time: Double) -> ScrollEvent {
        if stroke.keyCode == KeyCode.escape
            || (stroke.keyCode == KeyCode.leftBracket && stroke.modifiers.contains(.control))
        {
            return .exit
        }
        // Continuous scrolling is driven by a timer, not by key repeat.
        if stroke.isRepeat { return .ignored }

        let pendingG = firstGTime
        firstGTime = nil
        let shift = stroke.modifiers.contains(.shift)
        let control = stroke.modifiers.contains(.control)

        switch stroke.keyCode {
        case KeyCode.tab:
            return select(areaIndex + (shift ? -1 : 1))
        case KeyCode.downArrow:
            return select(areaIndex + 1)
        case KeyCode.upArrow:
            return select(areaIndex - 1)
        default:
            break
        }

        guard let character = stroke.character else { return .ignored }

        if control {
            switch character {
            case "n": return select(areaIndex + 1)
            case "p": return select(areaIndex - 1)
            default: return .ignored
            }
        }

        switch character {
        case "h": return start(.left, stroke, dash: shift)
        case "j": return start(.down, stroke, dash: shift)
        case "k": return start(.up, stroke, dash: shift)
        case "l": return start(.right, stroke, dash: shift)
        case "d": return .halfPage(.down)
        case "u": return .halfPage(.up)
        case "g":
            if shift { return .bottom }
            if let pendingG, time - pendingG <= Self.sequenceTimeout { return .top }
            firstGTime = time
            return .ignored
        default:
            if let digit = character.wholeNumberValue, digit < areaCount {
                areaIndex = digit
                return .selectArea(digit)
            }
            return .ignored
        }
    }

    public mutating func keyUp(keyCode: UInt16) -> ScrollEvent {
        guard keyCode == scrollingKey else { return .ignored }
        scrollingKey = nil
        return .stop
    }

    private mutating func start(_ direction: ScrollDirection, _ stroke: KeyStroke, dash: Bool) -> ScrollEvent {
        scrollingKey = stroke.keyCode
        return .start(direction, dash: dash)
    }

    private mutating func select(_ index: Int) -> ScrollEvent {
        // Wraps around in both directions.
        areaIndex = ((index % areaCount) + areaCount) % areaCount
        return .selectArea(areaIndex)
    }
}
