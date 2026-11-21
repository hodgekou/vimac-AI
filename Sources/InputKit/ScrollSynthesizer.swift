// Derived from ChunkyScroller.swift in Vimac (https://github.com/nchudleigh/vimac),
// Copyright © 2020 Dexter Leng, licensed under GPL-3.0.

import CoreGraphics
import Foundation
import VimacCore

/// Posts pixel-precise scroll wheel events. They land on whatever is under the cursor.
@MainActor
public final class ScrollSynthesizer {
    private static let tickInterval = 1.0 / 60.0

    private var timer: Timer?
    private var remainingTicks = 0

    public init() {}

    /// Scrolls `pixelsPerTick` in `direction` sixty times a second until `stop()`.
    public func start(_ direction: ScrollDirection, pixelsPerTick: Int, reverseHorizontal: Bool, reverseVertical: Bool) {
        let delta = Self.delta(direction, pixels: pixelsPerTick, reverseHorizontal: reverseHorizontal, reverseVertical: reverseVertical)
        run(ticks: nil, dx: delta.dx, dy: delta.dy)
    }

    /// Scrolls `pixels` in total, spread over a few frames so the motion is visible.
    public func scroll(_ direction: ScrollDirection, pixels: Int, reverseHorizontal: Bool, reverseVertical: Bool) {
        let ticks = 8
        let delta = Self.delta(direction, pixels: max(pixels / ticks, 1), reverseHorizontal: reverseHorizontal, reverseVertical: reverseVertical)
        run(ticks: ticks, dx: delta.dx, dy: delta.dy)
    }

    public func scrollToTop() {
        run(ticks: 3, dx: 0, dy: Int32(Int16.max))
    }

    public func scrollToBottom() {
        run(ticks: 3, dx: 0, dy: -Int32(Int16.max))
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        remainingTicks = 0
    }

    private func run(ticks: Int?, dx: Int32, dy: Int32) {
        stop()
        Self.post(dx: dx, dy: dy)
        if let ticks {
            remainingTicks = ticks - 1
            guard remainingTicks > 0 else { return }
        }
        let isBounded = ticks != nil
        timer = Timer.scheduledTimer(withTimeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                Self.post(dx: dx, dy: dy)
                if isBounded {
                    self.remainingTicks -= 1
                    if self.remainingTicks <= 0 { self.stop() }
                }
            }
        }
    }

    /// Positive `dy` moves the content down (towards the top of the document), positive `dx` moves it right.
    private static func delta(_ direction: ScrollDirection, pixels: Int, reverseHorizontal: Bool, reverseVertical: Bool) -> (dx: Int32, dy: Int32) {
        let amount = Int32(clamping: pixels)
        let horizontal: Int32 = reverseHorizontal ? -1 : 1
        let vertical: Int32 = reverseVertical ? -1 : 1
        switch direction {
        case .left: return (amount * horizontal, 0)
        case .right: return (-amount * horizontal, 0)
        case .up: return (0, amount * vertical)
        case .down: return (0, -amount * vertical)
        }
    }

    private static func post(dx: Int32, dy: Int32) {
        CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: dy, wheel2: dx, wheel3: 0)?
            .post(tap: .cghidEventTap)
    }
}
