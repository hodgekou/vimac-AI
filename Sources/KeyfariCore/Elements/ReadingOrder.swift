// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics

public enum ReadingOrder {
    /// Sorts elements top to bottom, and left to right within a row.
    public static func sorted(_ elements: [ElementSnapshot]) -> [ElementSnapshot] {
        // Elements whose click points fall in the same 12-point band count as one row.
        func key(_ element: ElementSnapshot) -> (Int, CGFloat) {
            (Int((element.clickPoint.y / 12).rounded(.down)), element.clickPoint.x)
        }
        return elements.sorted { key($0) < key($1) }
    }
}
