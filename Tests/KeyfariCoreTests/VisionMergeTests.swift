// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics
import Testing

@testable import KeyfariCore

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
            CGRect(x: 20, y: 8, width: 60, height: 14),  // the title of the existing button
            CGRect(x: 0, y: 100, width: 80, height: 16),  // text nothing covers
            CGRect(x: 300, y: 300, width: 4, height: 4),  // noise
        ]
        #expect(VisionMerge.newRegions(regions, existing: existing) == [1])
    }
}
