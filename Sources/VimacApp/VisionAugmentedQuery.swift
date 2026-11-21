import AXKit
import Foundation
import os
import ScreenVision
import VimacCore

/// Adds on-screen text that the accessibility tree does not expose to the elements of another query.
struct VisionAugmentedQuery: ElementQuerying {
    /// Below this many window elements the accessibility tree is considered empty.
    static let fallbackThreshold = 5

    let base: AXElementQuery
    let mode: VisionMode

    func hintableElements(pid: pid_t, bundleURL: URL?, otherPIDs: [pid_t]) async throws -> [ElementSnapshot] {
        var elements = try await base.hintableElements(pid: pid, bundleURL: bundleURL, otherPIDs: otherPIDs)
        guard mode != .off else { return elements }

        let log = Logger(subsystem: "dev.vimac-ai.Vimac", category: "vision")
        let windowElements = elements.filter { $0.source == .window }
        if mode == .fallback, windowElements.count >= Self.fallbackThreshold { return elements }
        guard ScreenTextDetector.hasPermission else {
            log.notice("Skipping vision detection: no Screen Recording permission")
            return elements
        }
        guard let windowFrame = AXElementQuery.focusedWindowFrame(pid: pid) else { return elements }

        let started = ContinuousClock.now
        let regions: [TextRegion]
        do {
            regions = try await ScreenTextDetector.textRegions(pid: pid, windowFrame: windowFrame)
        } catch {
            log.error("Vision detection failed: \(error.localizedDescription, privacy: .public)")
            return elements
        }
        try Task.checkCancellation()

        let kept = VisionMerge.newRegions(regions.map(\.frame), existing: windowElements.map(\.clippedFrame))
        elements.append(contentsOf: kept.map { index in
            ElementSnapshot(
                role: "VisionText",
                frame: regions[index].frame,
                searchText: regions[index].text,
                source: .vision
            )
        })
        let elapsed = ContinuousClock.now - started
        log.notice("Vision found \(regions.count) text regions, kept \(kept.count), after \(elapsed.description, privacy: .public)")
        return elements
    }
}
