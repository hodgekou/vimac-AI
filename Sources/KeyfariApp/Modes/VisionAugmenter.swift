// SPDX-License-Identifier: GPL-3.0-only

import AXKit
import Foundation
import KeyfariCore
import ScreenVision
import os

/// Finds on-screen text that the accessibility tree does not expose.
///
/// Recognition takes several hundred milliseconds, so it runs after the regular labels are
/// already on screen and its results are added to them.
struct VisionAugmenter: Sendable {
    /// Below this many window elements the accessibility tree is considered empty.
    static let fallbackThreshold = 5

    let mode: VisionMode

    /// Extra elements for the focused window of `pid`, excluding anything `existing` already covers.
    /// Returns nothing when detection is off, not needed, not permitted, or fails.
    func additionalElements(pid: pid_t, existing: [ElementSnapshot]) async -> [ElementSnapshot] {
        guard mode != .off else { return [] }
        let log = Logger(subsystem: "app.keyfari.Keyfari", category: "vision")

        let windowElements = existing.filter { $0.source == .window }
        if mode == .fallback, windowElements.count >= Self.fallbackThreshold { return [] }
        guard ScreenTextDetector.hasPermission else {
            log.notice("Skipping vision detection: no Screen Recording permission")
            return []
        }
        guard let windowFrame = AXElementQuery.focusedWindowFrame(pid: pid) else { return [] }

        let started = ContinuousClock.now
        let regions: [TextRegion]
        do {
            regions = try await ScreenTextDetector.textRegions(pid: pid, windowFrame: windowFrame)
        } catch {
            log.error("Vision detection failed: \(error.localizedDescription, privacy: .public)")
            return []
        }

        let kept = VisionMerge.newRegions(regions.map(\.frame), existing: windowElements.map(\.clippedFrame))
        let elapsed = ContinuousClock.now - started
        log.notice("Vision found \(regions.count) text regions, kept \(kept.count), after \(elapsed.description, privacy: .public)")
        return kept.map { index in
            ElementSnapshot(
                role: "VisionText",
                frame: regions[index].frame,
                searchText: regions[index].text,
                source: .vision
            )
        }
    }
}
