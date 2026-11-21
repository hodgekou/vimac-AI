// SPDX-License-Identifier: GPL-3.0-only
// The hintability rules are derived from ElementTree.swift in Vimac
// (https://github.com/nchudleigh/vimac), Copyright © 2021 Dexter Leng, licensed under GPL-3.0.

import CoreGraphics

public enum ElementSource: Sendable {
    case window
    case menuBar
    case menuBarExtra
    case notification
    case vision
}

/// An immutable description of one on-screen element. Frames use accessibility coordinates:
/// origin at the top-left of the primary display, y growing downward.
public struct ElementSnapshot: Sendable, Equatable {
    public let role: String
    public let frame: CGRect
    /// The part of `frame` that is not clipped by ancestors.
    public let clippedFrame: CGRect
    public let actions: [String]
    public let searchText: String
    public let source: ElementSource

    public init(
        role: String,
        frame: CGRect,
        clippedFrame: CGRect? = nil,
        actions: [String] = [],
        searchText: String = "",
        source: ElementSource = .window
    ) {
        self.role = role
        self.frame = frame
        self.clippedFrame = clippedFrame ?? frame
        self.actions = actions
        self.searchText = searchText
        self.source = source
    }

    /// Where a click lands and where the label is drawn.
    public var clickPoint: CGPoint {
        // A link can wrap over several lines, so its centre may be empty space.
        // Vimac clicks just inside the bottom-left corner instead, which is kept here.
        if role == "AXLink" {
            return CGPoint(x: frame.minX + 5, y: frame.maxY - 5)
        }
        return CGPoint(x: clippedFrame.midX, y: clippedFrame.midY)
    }
}

extension ElementSnapshot {
    /// Roles that take typed text. A click chain stops on them so that typing reaches the field.
    public var acceptsText: Bool {
        ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"].contains(role)
    }
}

public enum Hintability {
    /// Actions that every element advertises and that do not make it worth a label.
    static let ignoredActions: Set<String> = [
        "AXShowMenu", "AXScrollToVisible", "AXShowDefaultUI", "AXShowAlternateUI",
    ]

    static let excludedRoles: Set<String> = ["AXWindow", "AXScrollArea"]

    public static func isActionable(actions: [String]) -> Bool {
        actions.contains { !ignoredActions.contains($0) }
    }

    /// Returns the indices of the nodes that get a label, in depth-first order from `root`.
    ///
    /// A node is hintable when it has a meaningful action, or when it is a row
    /// with no hintable descendant (so that plain list rows stay clickable).
    public static func hintableIndices(
        roles: [String],
        actions: [[String]],
        children: [[Int]],
        root: Int
    ) -> [Int] {
        guard roles.indices.contains(root) else { return [] }
        var hintable = [Bool](repeating: false, count: roles.count)
        var descendantCount = [Int](repeating: 0, count: roles.count)

        // Children before parents, without recursion.
        var order: [Int] = []
        var stack = [root]
        while let node = stack.popLast() {
            order.append(node)
            stack.append(contentsOf: children[node])
        }

        for node in order.reversed() {
            var count = 0
            for child in children[node] {
                count += descendantCount[child] + (hintable[child] ? 1 : 0)
            }
            descendantCount[node] = count

            if excludedRoles.contains(roles[node]) { continue }
            hintable[node] =
                isActionable(actions: actions[node])
                || (roles[node] == "AXRow" && count == 0)
        }

        return order.filter { hintable[$0] }
    }
}
