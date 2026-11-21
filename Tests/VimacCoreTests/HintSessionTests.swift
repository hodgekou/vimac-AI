import CoreGraphics
import Testing
@testable import VimacCore

@Suite struct HintSessionTests {
    // Key codes on an ANSI keyboard.
    let a: UInt16 = 0, s: UInt16 = 1, d: UInt16 = 2, one: UInt16 = 18

    func session() -> HintSession {
        HintSession(labels: ["AA", "AS", "S", "D"])
    }

    @Test func singleCharacterLabelMatchesAtOnce() {
        var session = session()
        #expect(session.handle(KeyStroke(keyCode: s)) == .matched(index: 2, action: .left))
    }

    @Test func narrowsThenMatches() {
        var session = session()
        #expect(session.handle(KeyStroke(keyCode: a)) == .updated(prefix: "A", visible: [0, 1]))
        #expect(session.handle(KeyStroke(keyCode: s)) == .matched(index: 1, action: .left))
    }

    @Test func rejectsKeysThatMatchNothingAndKeepsPrefix() {
        var session = session()
        _ = session.handle(KeyStroke(keyCode: a))
        #expect(session.handle(KeyStroke(keyCode: d)) == .rejected)
        #expect(session.prefix == "A")
    }

    @Test func deleteRemovesLastCharacter() {
        var session = session()
        #expect(session.handle(KeyStroke(keyCode: KeyCode.delete)) == .ignored)
        _ = session.handle(KeyStroke(keyCode: a))
        #expect(session.handle(KeyStroke(keyCode: KeyCode.delete)) == .updated(prefix: "", visible: [0, 1, 2, 3]))
    }

    @Test func exitsOnEscapeAndControlBracket() {
        var session = session()
        #expect(session.handle(KeyStroke(keyCode: KeyCode.escape)) == .exit)
        #expect(session.handle(KeyStroke(keyCode: KeyCode.leftBracket, modifiers: .control)) == .exit)
        #expect(session.handle(KeyStroke(keyCode: KeyCode.leftBracket)) == .ignored)
    }

    @Test func spaceRotatesAndOtherKeysAreIgnored() {
        var session = session()
        #expect(session.handle(KeyStroke(keyCode: KeyCode.space)) == .rotate)
        #expect(session.handle(KeyStroke(keyCode: one)) == .ignored)
        #expect(session.handle(KeyStroke(keyCode: KeyCode.tab)) == .ignored)
    }

    @Test func ignoresAutoRepeat() {
        var session = session()
        #expect(session.handle(KeyStroke(keyCode: a, isRepeat: true)) == .ignored)
        #expect(session.prefix.isEmpty)
    }

    @Test(arguments: [
        (Modifiers([]), ClickAction.left),
        (Modifiers.shift, ClickAction.right),
        (Modifiers.command, ClickAction.double),
        (Modifiers.control, ClickAction.commandLeft),
        (Modifiers.option, ClickAction.moveOnly),
    ])
    func modifiersOnTheFinalKeySelectTheAction(modifiers: Modifiers, action: ClickAction) {
        var session = session()
        #expect(session.handle(KeyStroke(keyCode: d, modifiers: modifiers)) == .matched(index: 3, action: action))
    }
}

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
