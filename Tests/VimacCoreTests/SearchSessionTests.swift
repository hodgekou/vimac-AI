import CoreGraphics
import Testing
@testable import VimacCore

@Suite struct SearchSessionTests {
    // Key codes on an ANSI keyboard.
    let a: UInt16 = 0, s: UInt16 = 1, d: UInt16 = 2, e: UInt16 = 14, v: UInt16 = 9
    let n: UInt16 = 45, p: UInt16 = 35, eight: UInt16 = 28, semicolon: UInt16 = 41

    func session() -> SearchSession {
        // With the alphabet "sad", three matches are labelled S, A, D in order.
        SearchSession(texts: ["Save File", "Save As…", "Delete", "Open"], alphabet: "sad")
    }

    func type(_ keys: [UInt16], into session: inout SearchSession) {
        for key in keys { _ = session.handle(KeyStroke(keyCode: key)) }
    }

    @Test func normalizesCaseAndWhitespace() {
        #expect(SearchSession.normalize("  Save  File\n") == "savefile")
    }

    @Test func emptyQueryMatchesNothing() {
        let session = session()
        #expect(session.matches.isEmpty)
        #expect(session.focus == nil)
    }

    @Test func filtersBySubstringAndFocusesTheFirstMatch() {
        var session = session()
        #expect(session.handle(KeyStroke(keyCode: s)) == .updated)
        type([a, v, e], into: &session)
        #expect(session.query == "save")
        #expect(session.matches == [0, 1])
        #expect(session.labels.count == 2)
        #expect(session.focusedIndex == 0)
    }

    @Test func asteriskAndSemicolonMatchEverything() {
        var first = session()
        _ = first.handle(KeyStroke(keyCode: eight, modifiers: .shift))
        #expect(first.matches == [0, 1, 2, 3])

        var second = session()
        _ = second.handle(KeyStroke(keyCode: semicolon))
        #expect(second.matches == [0, 1, 2, 3])
    }

    @Test func focusMovesAndWraps() {
        var session = session()
        type([s, a, v, e], into: &session)
        #expect(session.handle(KeyStroke(keyCode: KeyCode.tab)) == .updated)
        #expect(session.focusedIndex == 1)
        #expect(session.handle(KeyStroke(keyCode: KeyCode.downArrow)) == .updated)
        #expect(session.focusedIndex == 0)
        _ = session.handle(KeyStroke(keyCode: KeyCode.tab, modifiers: .shift))
        #expect(session.focusedIndex == 1)
        _ = session.handle(KeyStroke(keyCode: KeyCode.upArrow))
        #expect(session.focusedIndex == 0)
        _ = session.handle(KeyStroke(keyCode: n, modifiers: .control))
        #expect(session.focusedIndex == 1)
        _ = session.handle(KeyStroke(keyCode: p, modifiers: .control))
        #expect(session.focusedIndex == 0)
    }

    @Test func shiftLetterJumpsFocusToALabel() {
        var session = session()
        type([e], into: &session)
        // "e" matches Save File, Save As…, Delete, Open; three letters cannot label four, so labels have two characters.
        #expect(session.matches.count == 4)
        let target = session.labels[2]
        for character in target {
            let keyCode: UInt16 = character == "S" ? s : character == "A" ? a : d
            #expect(session.handle(KeyStroke(keyCode: keyCode, modifiers: .shift)) == .updated)
        }
        #expect(session.focus == 2)
        #expect(session.labelPrefix.isEmpty)
        // Shift-letters never change the query.
        #expect(session.query == "e")
    }

    @Test func labelKeyThatMatchesNothingIsRejected() {
        var session = session()
        type([s, a, v, e], into: &session)
        #expect(session.handle(KeyStroke(keyCode: e, modifiers: .shift)) == .rejected)
    }

    @Test func returnActsOnTheFocusedMatch() {
        var session = session()
        #expect(session.handle(KeyStroke(keyCode: KeyCode.return)) == .ignored)
        type([d, e], into: &session)
        #expect(session.matches == [2])
        #expect(session.handle(KeyStroke(keyCode: KeyCode.return)) == .act(index: 2, action: .left))
        #expect(session.handle(KeyStroke(keyCode: KeyCode.return, modifiers: .shift)) == .act(index: 2, action: .right))
        #expect(session.handle(KeyStroke(keyCode: KeyCode.return, modifiers: .command)) == .act(index: 2, action: .commandLeft))
        #expect(session.handle(KeyStroke(keyCode: KeyCode.return, modifiers: .option)) == .act(index: 2, action: .moveOnly))
    }

    @Test func deleteShortensTheLabelPrefixBeforeTheQuery() {
        var session = session()
        type([e], into: &session)
        _ = session.handle(KeyStroke(keyCode: s, modifiers: .shift))
        #expect(session.labelPrefix == "S")
        #expect(session.handle(KeyStroke(keyCode: KeyCode.delete)) == .updated)
        #expect(session.labelPrefix.isEmpty)
        #expect(session.query == "e")
        #expect(session.handle(KeyStroke(keyCode: KeyCode.delete)) == .updated)
        #expect(session.query.isEmpty)
        #expect(session.handle(KeyStroke(keyCode: KeyCode.delete)) == .ignored)
    }

    @Test func exits() {
        var session = session()
        #expect(session.handle(KeyStroke(keyCode: KeyCode.escape)) == .exit)
        #expect(session.handle(KeyStroke(keyCode: KeyCode.leftBracket, modifiers: .control)) == .exit)
    }

    @Test func readingOrderGoesRowByRow() {
        func button(_ x: CGFloat, _ y: CGFloat) -> ElementSnapshot {
            ElementSnapshot(role: "AXButton", frame: CGRect(x: x, y: y, width: 10, height: 10))
        }
        let sorted = ReadingOrder.sorted([button(300, 100), button(10, 200), button(20, 102), button(5, 20)])
        #expect(sorted.map(\.frame.origin.x) == [5, 20, 300, 10])
    }

    @Test func chineseTextIsFoundByPinyin() {
        #expect(SearchSession.searchForms("Save") == ["save"])
        let forms = SearchSession.searchForms("保存")
        #expect(forms.contains("保存"))
        #expect(forms.contains("baocun"))
        #expect(forms.contains("bc"))

        var session = SearchSession(texts: ["保存", "取消", "Open"], alphabet: "sad")
        // b, c
        _ = session.handle(KeyStroke(keyCode: 11))
        _ = session.handle(KeyStroke(keyCode: 8))
        #expect(session.matches == [0])
    }

    @Test func textRolesAcceptText() {
        #expect(ElementSnapshot(role: "AXTextField", frame: .zero).acceptsText)
        #expect(!ElementSnapshot(role: "AXButton", frame: .zero).acceptsText)
    }
}
