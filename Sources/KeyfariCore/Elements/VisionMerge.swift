// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics

/// Combines text found on screen with the elements the accessibility tree already provides.
public enum VisionMerge {
    public static func intersectionOverUnion(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let intersection = a.intersection(b)
        guard !intersection.isNull, !intersection.isEmpty else { return 0 }
        let overlap = intersection.width * intersection.height
        let union = a.width * a.height + b.width * b.height - overlap
        return union > 0 ? overlap / union : 0
    }

    /// Returns the regions worth a label of their own.
    ///
    /// A region is dropped when it is tiny, when it overlaps an existing element heavily, or when
    /// its centre lies inside one: that is the title of a button which already has a label.
    public static func newRegions(
        _ regions: [CGRect],
        existing: [CGRect],
        minimumSide: CGFloat = 8,
        overlapThreshold: CGFloat = 0.5
    ) -> [Int] {
        regions.indices.filter { index in
            let region = regions[index]
            guard region.width >= minimumSide, region.height >= minimumSide else { return false }
            let center = CGPoint(x: region.midX, y: region.midY)
            return !existing.contains { frame in
                frame.contains(center) || intersectionOverUnion(frame, region) > overlapThreshold
            }
        }
    }
}
