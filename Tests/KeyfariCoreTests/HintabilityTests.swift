// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics
import Testing

@testable import KeyfariCore

@Suite struct HintabilityTests {
    @Test func elementsWithOnlyIgnoredActionsAreNotHintable() {
        #expect(!Hintability.isActionable(actions: ["AXShowMenu", "AXScrollToVisible"]))
        #expect(Hintability.isActionable(actions: ["AXShowMenu", "AXPress"]))
    }

    @Test func picksActionableNodesAndBareRows() {
        // 0 window ─ 1 scroll area ─ 2 row ─ 3 button
        //                          └ 4 row ─ 5 static text
        //          └ 6 group (no actions)
        let roles = ["AXWindow", "AXScrollArea", "AXRow", "AXButton", "AXRow", "AXStaticText", "AXGroup"]
        let actions: [[String]] = [["AXRaise"], ["AXPress"], [], ["AXPress"], [], [], []]
        let children: [[Int]] = [[1, 6], [2, 4], [3], [], [5], [], []]

        let result = Hintability.hintableIndices(roles: roles, actions: actions, children: children, root: 0)
        // The window and scroll area are excluded even though they have actions.
        // Row 2 is skipped because its button is hintable; row 4 has no hintable descendant.
        #expect(Set(result) == [3, 4])
    }

    @Test func linkClicksNearItsFirstLine() {
        let link = ElementSnapshot(role: "AXLink", frame: CGRect(x: 100, y: 200, width: 300, height: 40))
        #expect(link.clickPoint == CGPoint(x: 105, y: 235))

        let button = ElementSnapshot(
            role: "AXButton",
            frame: CGRect(x: 0, y: 0, width: 100, height: 100),
            clippedFrame: CGRect(x: 0, y: 0, width: 100, height: 50)
        )
        #expect(button.clickPoint == CGPoint(x: 50, y: 25))
    }
}
