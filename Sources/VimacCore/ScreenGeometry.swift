import CoreGraphics

/// Converts between the two coordinate spaces the app deals with.
///
/// Accessibility and Quartz events use a top-left origin on the primary display with y growing downward.
/// AppKit uses a bottom-left origin on the primary display with y growing upward.
public enum ScreenGeometry {
    /// Flips a rectangle between the accessibility space and the AppKit space.
    /// The conversion is its own inverse.
    public static func flipped(_ rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: primaryScreenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    public static func center(of rect: CGRect) -> CGPoint {
        CGPoint(x: rect.midX, y: rect.midY)
    }

    /// Index of the screen frame that contains the largest part of `rect`, or nil when none intersects it.
    public static func indexOfScreen(containing rect: CGRect, screenFrames: [CGRect]) -> Int? {
        var best: (index: Int, area: CGFloat)?
        for (index, frame) in screenFrames.enumerated() {
            let overlap = frame.intersection(rect)
            guard !overlap.isNull, !overlap.isEmpty else { continue }
            let area = overlap.width * overlap.height
            if best == nil || area > best!.area {
                best = (index, area)
            }
        }
        return best?.index
    }
}
